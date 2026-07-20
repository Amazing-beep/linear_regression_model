import os
import joblib
import pandas as pd
import numpy as np
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Literal, List
from sklearn.metrics import root_mean_squared_error

app = FastAPI(
    title="Student Reading Score Predictor API",
    description="This API predicts 15-year-old student reading scores using machine learning models trained on PISA 2009 data.",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# ---------------------------------------------------------
# CORS MIDDLEWARE CONFIGURATION
# ---------------------------------------------------------
# RATIONALE & SECURITY REASONING:
# 1. allow_origins: We explicitly restrict allowed origins to specific trusted domain names 
#    and local development hosts (e.g. Flutter web clients, localhost on common ports like 8080/3000) 
#    instead of using "*" (wildcard), which would allow any third-party domain to access our API.
# 2. allow_credentials: Set to True to support secure cookies, tokens, and authorization.
# 3. allow_methods: Restricts cross-origin requests to only GET and POST. This blocks dangerous methods 
#    like PUT, DELETE, and PATCH from untrusted sources, protecting our training dataset and model states.
# 4. allow_headers: Explicitly restricted to Content-Type and Authorization to prevent cross-site scripting (XSS) 
#    and custom headers injection.
origins = [
    "http://localhost",
    "http://localhost:8080",
    "http://127.0.0.1:8080",
    "http://localhost:3000",
    "https://my-student-predictor.web.app",  # Production/Staging Flutter Web client URL
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "Authorization"],
)

# Load model and preprocessor
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(BASE_DIR, "best_model.joblib")
PREPROCESSOR_PATH = os.path.join(BASE_DIR, "preprocessor.joblib")

# Fallback paths for direct relative execution
if not os.path.exists(MODEL_PATH) or not os.path.exists(PREPROCESSOR_PATH):
    # Try parent directory in case of execution context differences
    MODEL_PATH = os.path.join(BASE_DIR, "..", "models", "best_model.joblib")
    PREPROCESSOR_PATH = os.path.join(BASE_DIR, "..", "models", "preprocessor.joblib")

if not os.path.exists(MODEL_PATH) or not os.path.exists(PREPROCESSOR_PATH):
    # Ensure they are loaded from local API folder where they were saved by default
    MODEL_PATH = os.path.join(BASE_DIR, "best_model.joblib")
    PREPROCESSOR_PATH = os.path.join(BASE_DIR, "preprocessor.joblib")

try:
    model = joblib.load(MODEL_PATH)
    preprocessor = joblib.load(PREPROCESSOR_PATH)
except Exception as e:
    # We will load dynamically when request is made if training was just run
    model = None
    preprocessor = None

def load_models_lazy():
    global model, preprocessor
    if model is None or preprocessor is None:
        if os.path.exists(MODEL_PATH) and os.path.exists(PREPROCESSOR_PATH):
            model = joblib.load(MODEL_PATH)
            preprocessor = joblib.load(PREPROCESSOR_PATH)
        else:
            raise RuntimeError(f"Model files not found at {MODEL_PATH}. Run training first.")

# ---------------------------------------------------------
# PYDANTIC MODEL SCHEMAS
# ---------------------------------------------------------
# Data types and range constraints are strictly enforced using Pydantic Field
class PredictionInput(BaseModel):
    grade: int = Field(
        ..., 
        ge=8, 
        le=12, 
        description="The student's school grade level. Must be between 8 and 12.",
        json_schema_extra={"example": 10}
    )
    male: int = Field(
        ..., 
        ge=0, 
        le=1, 
        description="Student gender indicator (0 for Female, 1 for Male).",
        json_schema_extra={"example": 0}
    )
    raceeth: Literal[
        "White", "Hispanic", "Black", "Asian", "More than one race", 
        "American Indian/Alaska Native", "Native Hawaiian/Other Pacific Islander"
    ] = Field(
        ..., 
        description="Categorical variable for student race/ethnicity.",
        json_schema_extra={"example": "White"}
    )
    expectBachelors: float = Field(
        ..., 
        ge=0.0, 
        le=1.0, 
        description="Student expects to get a Bachelor's degree (0.0 for No, 1.0 for Yes).",
        json_schema_extra={"example": 1.0}
    )
    read30MinsADay: float = Field(
        ..., 
        ge=0.0, 
        le=1.0, 
        description="Reads for pleasure at least 30 minutes daily (0.0 for No, 1.0 for Yes).",
        json_schema_extra={"example": 1.0}
    )
    minutesPerWeekEnglish: float = Field(
        ..., 
        ge=0.0, 
        le=3000.0, 
        description="Weekly instruction minutes in English class.",
        json_schema_extra={"example": 250.0}
    )
    studentsInEnglish: float = Field(
        ..., 
        ge=0.0, 
        le=100.0, 
        description="Number of students in English class.",
        json_schema_extra={"example": 25.0}
    )
    schoolSize: float = Field(
        ..., 
        ge=0.0, 
        le=10000.0, 
        description="Total student enrollment at school.",
        json_schema_extra={"example": 1200.0}
    )

class PredictionOutput(BaseModel):
    predicted_reading_score: float
    model_version: str

class RetrainItem(PredictionInput):
    readingScore: float = Field(
        ..., 
        ge=0.0, 
        le=1000.0, 
        description="Actual reading score of the student to append for retraining.",
        json_schema_extra={"example": 540.2}
    )

# ---------------------------------------------------------
# ENDPOINTS
# ---------------------------------------------------------
@app.get("/")
def read_root():
    return {
        "status": "online",
        "service": "Student Reading Score Predictor API",
        "documentation": "/docs"
    }

@app.post("/predict", response_model=PredictionOutput)
def predict(data: PredictionInput):
    load_models_lazy()
    # Convert input schema into DataFrame matching the training layout
    input_dict = {
        "grade": [data.grade],
        "male": [data.male],
        "raceeth": [data.raceeth],
        "expectBachelors": [data.expectBachelors],
        "read30MinsADay": [data.read30MinsADay],
        "minutesPerWeekEnglish": [data.minutesPerWeekEnglish],
        "studentsInEnglish": [data.studentsInEnglish],
        "schoolSize": [data.schoolSize],
    }
    df = pd.DataFrame(input_dict)
    
    try:
        # Preprocess input data point
        X_preprocessed = preprocessor.transform(df)
        # Predict using loaded model
        prediction = model.predict(X_preprocessed)[0]
        return PredictionOutput(
            predicted_reading_score=float(prediction),
            model_version="Random Forest v1.0"
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prediction error: {str(e)}")

@app.post("/retrain")
def retrain_model(new_data: List[RetrainItem]):
    global model, preprocessor
    load_models_lazy()
    
    if not new_data:
        raise HTTPException(status_code=400, detail="No retraining data was provided.")
        
    try:
        # Convert items to list of dicts
        records = []
        for item in new_data:
            records.append({
                "grade": item.grade,
                "male": item.male,
                "raceeth": item.raceeth,
                "expectBachelors": item.expectBachelors,
                "read30MinsADay": item.read30MinsADay,
                "minutesPerWeekEnglish": item.minutesPerWeekEnglish,
                "studentsInEnglish": item.studentsInEnglish,
                "schoolSize": item.schoolSize,
                "readingScore": item.readingScore
            })
        new_df = pd.DataFrame(records)
        
        # Locate train CSV path relative to API folder
        train_csv_path = os.path.join(BASE_DIR, "..", "linear_regression", "data", "pisa2009train.csv")
        test_csv_path = os.path.join(BASE_DIR, "..", "linear_regression", "data", "pisa2009test.csv")
        
        if not os.path.exists(train_csv_path):
            raise FileNotFoundError(f"Training dataset not found at expected path: {train_csv_path}")
            
        # Append to training CSV
        new_df.to_csv(train_csv_path, mode='a', header=False, index=False)
        
        # Reload expanded dataset
        df_train = pd.read_csv(train_csv_path)
        df_test = pd.read_csv(test_csv_path)
        
        # Remove any rows with missing targets
        df_train = df_train.dropna(subset=['readingScore'])
        df_test = df_test.dropna(subset=['readingScore'])
        
        features = ['grade', 'male', 'raceeth', 'expectBachelors', 'read30MinsADay', 
                    'minutesPerWeekEnglish', 'studentsInEnglish', 'schoolSize']
        target = 'readingScore'
        
        X_train = df_train[features]
        y_train = df_train[target]
        X_test = df_test[features]
        y_test = df_test[target]
        
        # Fit preprocessor on expanded dataset
        X_train_preprocessed = preprocessor.fit_transform(X_train)
        X_test_preprocessed = preprocessor.transform(X_test)
        
        # Retrain active model instance
        model.fit(X_train_preprocessed, y_train)
        
        # Save updated preprocessor and model
        joblib.dump(preprocessor, PREPROCESSOR_PATH)
        joblib.dump(model, MODEL_PATH)
        
        # Re-evaluate loss metrics
        train_rmse = root_mean_squared_error(y_train, model.predict(X_train_preprocessed))
        test_rmse = root_mean_squared_error(y_test, model.predict(X_test_preprocessed))
        
        return {
            "status": "success",
            "message": f"Successfully retrained the model with {len(new_data)} streaming/uploaded items.",
            "metrics": {
                "new_train_rmse": float(train_rmse),
                "new_test_rmse": float(test_rmse),
                "total_train_samples": len(df_train)
            }
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Retraining engine error: {str(e)}")
