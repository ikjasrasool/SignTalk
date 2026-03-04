from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
import pickle
import cv2
import numpy as np
import mediapipe as mp

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Load your trained model ──────────────────────────────────
model_dict = pickle.load(open('model.p', 'rb'))
model = model_dict['model']

# ── Labels (same as your inference_classifier.py) ───────────
labels_dict = {
    0: 'A', 1: 'B', 2: 'C', 3: 'D', 4: 'E', 5: 'F', 6: 'G',
    7: 'H', 8: 'I', 9: 'J', 10: 'K', 11: 'L', 12: 'M', 13: 'N',
    14: 'O', 15: 'P', 16: 'Q', 17: 'R', 18: 'S', 19: 'T', 20: 'U',
    21: 'V', 22: 'W', 23: 'X', 24: 'Y', 25: 'Z', 26: 'Hello',
    27: 'Done', 28: 'Thank You', 29: 'I Love you', 30: 'Sorry',
    31: 'Please', 32: 'You are welcome.'
}

# ── Mediapipe setup ──────────────────────────────────────────
mp_hands = mp.solutions.hands
hands = mp_hands.Hands(
    static_image_mode=True,
    max_num_hands=1,
    min_detection_confidence=0.3
)


@app.get("/")
def root():
    return {"status": "Sign2Text API is running on HuggingFace 🚀"}


@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    try:
        # Read uploaded image bytes
        contents = await file.read()
        np_arr = np.frombuffer(contents, np.uint8)
        img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)

        if img is None:
            return {"success": False, "error": "Invalid image", "prediction": None, "confidence": 0.0}

        img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        results = hands.process(img_rgb)

        if not results.multi_hand_landmarks:
            return {"success": False, "prediction": None, "confidence": 0.0, "error": "No hand detected"}

        data_aux, x_, y_ = [], [], []

        for hand_landmarks in results.multi_hand_landmarks:
            for lm in hand_landmarks.landmark:
                x_.append(lm.x)
                y_.append(lm.y)
            for lm in hand_landmarks.landmark:
                data_aux.append(lm.x - min(x_))
                data_aux.append(lm.y - min(y_))

        prediction = model.predict([np.asarray(data_aux)])
        prediction_proba = model.predict_proba([np.asarray(data_aux)])
        confidence = float(max(prediction_proba[0]))
        predicted_label = labels_dict[int(prediction[0])]

        return {
            "success": True,
            "prediction": predicted_label,
            "confidence": confidence
        }

    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "prediction": None,
            "confidence": 0.0
        }