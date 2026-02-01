import numpy as np
import cv2
import mediapipe as mp
from tensorflow.keras.models import load_model
from tensorflow.keras.layers import LSTM
from sklearn.preprocessing import LabelEncoder
from collections import Counter
from moviepy.editor import VideoFileClip
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import google.generativeai as genai
import os
import tempfile
import logging
from typing import List, Tuple, Optional
from contextlib import asynccontextmanager
import traceback

# ----------------- Logging Setup -----------------
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ----------------- Global Variables -----------------
model = None
label_encoder = None
mp_holistic = None
genai_model = None

# ----------------- Lifespan Context Manager -----------------
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load models on startup and cleanup on shutdown"""
    global model, label_encoder, mp_holistic, genai_model

    logger.info("Loading models...")

    # Load LSTM model
    def custom_lstm(*args, **kwargs):
        kwargs.pop('time_major', None)
        return LSTM(*args, **kwargs)

    custom_objects = {'LSTM': custom_lstm}
    model = load_model('cropped_POC.keras', custom_objects=custom_objects)
    logger.info("LSTM model loaded successfully")

    # Setup Label Encoder
    label_encoder = LabelEncoder()
    label_encoder.fit(['Morning', 'Blind', 'happy', 'he', 'she', 'it', 'I', 'Deaf', 'combined', 'Night'])
    logger.info("Label encoder initialized")

    # Setup MediaPipe
    mp_holistic = mp.solutions.holistic
    logger.info("MediaPipe initialized")

    # Setup Google Gemini API
    API_KEY = os.getenv("GEMINI_API_KEY", "AIzaSyCuWMeLjjC_Ta2WI2dQqIyOO4uniczU528")
    genai.configure(api_key=API_KEY)
    genai_model = genai.GenerativeModel("gemini-1.5-flash")
    logger.info("Gemini API configured")

    yield

    logger.info("Shutting down...")

# ----------------- FastAPI Setup -----------------
app = FastAPI(
    title="Sign Language Prediction API",
    description="API for predicting sign language from videos",
    version="1.0.0",
    lifespan=lifespan
)

# Add CORS middleware - IMPORTANT for mobile apps
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for mobile apps
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ----------------- Helper Functions -----------------
def get_bounding_box(landmarks: List, image_width: int, image_height: int) -> List[List[float]]:
    x_coords = [lm[0] * image_width for lm in landmarks]
    y_coords = [lm[1] * image_height for lm in landmarks]

    x_min = max(min(x_coords) - 20, 0)
    x_max = min(max(x_coords) + 20, image_width)
    y_min = max(min(y_coords) - 20, 0)
    y_max = min(max(y_coords) + 20, image_height)

    width = x_max - x_min
    height = y_max - y_min

    if width == 0 or height == 0:
        return []

    coordinates = [[(x - x_min) / width, (y - y_min) / height] for x, y in zip(x_coords, y_coords)]
    return coordinates

def extract_hand_landmarks(frame: np.ndarray, holistic) -> Tuple[Optional[np.ndarray], np.ndarray]:
    try:
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        image_height, image_width, _ = rgb_frame.shape
        results = holistic.process(rgb_frame)
        landmarks = []

        if results.left_hand_landmarks:
            left_coords = [[lm.x, lm.y, lm.z] for lm in results.left_hand_landmarks.landmark]
            left_bbox = get_bounding_box(left_coords, image_width, image_height)
            if left_bbox:
                landmarks.extend(left_bbox)

        if results.right_hand_landmarks:
            right_coords = [[lm.x, lm.y, lm.z] for lm in results.right_hand_landmarks.landmark]
            right_bbox = get_bounding_box(right_coords, image_width, image_height)
            if right_bbox:
                landmarks.extend(right_bbox)

        if len(landmarks) > 0:
            while len(landmarks) < 42:
                landmarks.append([0.0, 0.0])
            return np.array(landmarks[:42]), frame
        else:
            return None, frame
    except Exception as e:
        logger.error(f"Error extracting landmarks: {e}")
        return None, frame

def process_video(video_path: str, holistic) -> np.ndarray:
    cap = cv2.VideoCapture(video_path)
    landmarks_list = []
    frame_count = 0

    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break
        frame_count += 1
        landmarks, _ = extract_hand_landmarks(frame, holistic)
        if landmarks is not None:
            landmarks_list.append(landmarks)

    cap.release()
    logger.info(f"Total frames: {frame_count}, Frames with hands: {len(landmarks_list)}")
    return np.array(landmarks_list)

def predict_signs(landmarks: np.ndarray) -> List[Tuple[str, float]]:
    predictions = []
    for i, frame_landmarks in enumerate(landmarks):
        frame_landmarks = np.expand_dims(frame_landmarks, axis=0)
        pred = model.predict(frame_landmarks, verbose=0)
        label_idx = np.argmax(pred, axis=-1)[0]
        accuracy = np.max(pred, axis=-1)[0]
        label = label_encoder.inverse_transform([label_idx])[0]
        predictions.append((label, float(accuracy)))
    return predictions

def segment_video(predicted_signs: List[Tuple[str, float]], fps: float, window_duration: float = 2.0) -> List[str]:
    window_size = max(int(fps * window_duration), 1)
    segmented = []

    for i in range(0, len(predicted_signs), window_size):
        window = predicted_signs[i:i + window_size]
        filtered = [sign for sign, conf in window if conf >= 0.5]
        if len(filtered) == 0:
            filtered = [sign for sign, conf in window]
        if filtered:
            most_common = Counter(filtered).most_common(1)[0][0]
            segmented.append(most_common)
    return segmented

def remove_consecutive_duplicates(signs: List[str]) -> List[str]:
    filtered = []
    prev = None
    for sign in signs:
        if sign != prev:
            filtered.append(sign)
            prev = sign
    return filtered

def generate_sentence(keywords: List[str]) -> str:
    try:
        request_text = f"Generate a single probable sentence from these sign language keywords: [{', '.join(keywords)}]. Keep it natural and grammatically correct."
        response = genai_model.generate_content(request_text)
        return response.text.strip()
    except Exception as e:
        logger.error(f"Error generating sentence: {e}")
        return " ".join(keywords)

# ----------------- API Endpoints -----------------
@app.get("/")
async def root():
    return {"message": "Sign Language Prediction API", "version": "1.0.0", "status": "running"}

@app.get("/health")
async def health_check():
    return {"status": "healthy", "model_loaded": model is not None, "label_encoder_loaded": label_encoder is not None}

@app.post("/predict_signs/")
async def predict_signs_endpoint(file: UploadFile = File(...)):
    temp_video_path = None
    try:
        logger.info(f"Received file: {file.filename}, Content-Type: {file.content_type}")
        if not file.filename:
            raise HTTPException(status_code=400, detail="No filename provided")
        content = await file.read()
        if len(content) == 0:
            raise HTTPException(status_code=400, detail="Empty file uploaded")

        file_extension = os.path.splitext(file.filename)[1] or '.mp4'
        with tempfile.NamedTemporaryFile(delete=False, suffix=file_extension) as temp_file:
            temp_video_path = temp_file.name
            temp_file.write(content)
        logger.info(f"Video saved to: {temp_video_path}")

        holistic = mp_holistic.Holistic(static_image_mode=False, min_detection_confidence=0.5, min_tracking_confidence=0.5)
        landmarks = process_video(temp_video_path, holistic)

        if len(landmarks) == 0:
            return JSONResponse(status_code=200, content={"success": False, "message": "No hand detected in videos.", "predicted_signs": [], "sentence": ""})

        predicted_signs = predict_signs(landmarks)

        try:
            video_clip = VideoFileClip(temp_video_path)
            fps = video_clip.fps
            video_clip.close()
        except Exception:
            fps = 30.0

        segmented = segment_video(predicted_signs, fps)
        final_output = remove_consecutive_duplicates(segmented)

        if len(final_output) > 1:
            sentence = generate_sentence(final_output)
        elif len(final_output) == 1:
            sentence = final_output[0]
        else:
            sentence = ""

        return JSONResponse(content={
            "success": bool(final_output),
            "predicted_signs": final_output,
            "sentence": sentence,
            "total_frames": len(landmarks),
            "fps": fps
        })

    except HTTPException as he:
        logger.error(f"HTTP Exception: {he.detail}")
        raise he
    except Exception as e:
        logger.error(f"Error processing videos: {str(e)}")
        logger.error(traceback.format_exc())
        return JSONResponse(status_code=500, content={"success": False, "message": f"Error processing videos: {str(e)}", "predicted_signs": [], "sentence": ""})
    finally:
        if temp_video_path and os.path.exists(temp_video_path):
            try:
                os.remove(temp_video_path)
                logger.info(f"Cleaned up temp file: {temp_video_path}")
            except Exception as e:
                logger.warning(f"Could not delete temp file: {e}")

# ----------------- Run Server -----------------
if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=7000, log_level="info", timeout_keep_alive=300)