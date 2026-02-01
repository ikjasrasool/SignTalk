

# 🧠🤟 **SignTalk – Real-Time Speech ↔ Sign Language Translator**


SignTAlk is an AI-powered mobile application that enables **real-time two-way translation** between **Speech/Text → Sign Language** and **Sign Language → Text** using **3D animated avatars** and **gesture recognition**.

This project is built to support communication for the **hearing-impaired community**, promoting accessibility and inclusivity using modern AI and 3D animation.

---

## 🚀 **Features**

### 🔊 → 🤟 **Speech/Text to Sign Language**

* Converts **voice input** to text
* Maps text to **Indian Sign Language (ISL)** grammar
* Displays signs using a **3D animated avatar**
* Falls back to **alphabet-level signs** when full words aren't available
* Supports **150+ vocabulary signs** (extendable)

### 🤟 → 📝 **Sign Language to Text**

* Captures gestures using the mobile camera
* **MediaPipe** detects hand & facial landmarks
* Deep learning model (LSTM + GNN) predicts words
* Reconstructs natural language sentences in real-time

### 📱 **Mobile Application**

* Built using **Flutter (Dart)**
* Backend powered by **FastAPI**
* Smooth UI/UX and responsive animations

### 🎥 **3D Avatar Animation**

* Custom ISL gestures built using **Blender 3D**
* Smooth transition animations
* Used for real-time sign visualization

---

## 🧩 **Project Modules**

### **1. Speech → Text**

* Automatic Speech Recognition (ASR)
* Text preprocessing
* Tokenization & ISL grammar transformation

### **2. Text → Sign Language**

* Maps input text into ISL-compatible grammar
* Word-level & alphabet-level sign video mapping
* Generates final animated avatar video

### **3. Sign Language → Text**

* Hand + face landmark extraction using MediaPipe
* PCA-based feature processing
* LSTM + GNN hybrid model for gesture recognition
* Outputs final text sentences

### **4. 3D Avatar Animation**

* Blender-based custom animations
* Exported as MP4 for use in mobile app

---

## 🏗️ **Tech Stack**

### **Frontend**

* Flutter (Dart)

### **Backend**

* FastAPI (Python)
* MediaPipe
* TensorFlow / PyTorch
* VideoPi (sign video mapping)

### **AI / ML**

* LSTM + GNN Hybrid Model
* PCA feature extraction
* Gesture recognition pipeline

### **3D Modeling**

* Blender 3D
* Custom ISL animations

---

## 📊 **Results**

| Module                          | Metrics                 |
| ------------------------------- | ----------------------- |
| **Sign → Text Model Accuracy**  | ~78%                    |
| **PCA Features Retained**       | 30 key gesture features |
| **Word Error Rate (WER)**       | < 1%                    |
| **Character Error Rate (CER)**  | < 0.5%                  |
| **Speech → Sign Response Time** | ~2 seconds              |
| **Vocabulary Support**          | 150+ signs              |

---

## 🗂️ **Repository Structure**

```
SignifyAI/
│── sign/                # Flutter frontend
│── signToText/          # Sign → Text Recognition Module
│── textToSign/          # Text/Speech → Sign Module
│── README.md            # Project documentation
```

---

## 📦 **Dataset Used**

### 🖐️ **1. Sign Language → Text Dataset**

* Indian Sign Language (ISL) gesture videos
* Used for training the LSTM+GNN model

### 🎞️ **2. Text/Speech → Sign Dataset**

* ISL animated reference videos
* Extended with custom **Blender animations**

---

## 🔧 **How It Works**

### **Voice → Sign Pipeline**

1. User speaks into the mobile app
2. Speech is converted to text
3. Text converted to ISL grammar
4. Word or alphabet videos are mapped
5. 3D avatar animation is displayed

### **Sign → Text Pipeline**

1. Camera captures sign gestures
2. MediaPipe extracts hand & face coordinates
3. Model predicts gesture → word
4. Words combined into sentences
5. Display final text output

---

## 👨‍💻 **Contributors**

| Name                           | Contributors                        |
| ------------------------------ | ---------------------------- |
| **Ikjas Rasool P**            | [ikjasrasool](https://github.com/ikjasrasool)     |
| **Kamaleshwaran A**            | [kamaleshwaran-A](https://github.com/kamaleshwaran-A) |
| **Krishnan P**                | [KRISHNAPALANISAMY](https://github.com/KRISHNAPALANISAMY)|


---

## ⭐ **Support & Contributions**

You are welcome to:

* ⭐ Star the repository
* 🍴 Fork the project
* 🐛 Report issues
* 🤝 Contribute sign videos / datasets / code

---

## 🙏 **Thank You**

Your support helps us build more accessible AI solutions for everyone.

---

