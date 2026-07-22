import os
import joblib
import pandas as pd
import numpy as np
from fastapi import FastAPI, HTTPException, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from typing import Literal, List
from sklearn.metrics import root_mean_squared_error, r2_score
from sklearn.ensemble import RandomForestRegressor

# Initialize FastAPI application with metadata
app = FastAPI(
    title="Student Reading Score Predictor API",
    description="This production-ready API predicts 15-year-old student reading scores using machine learning models trained on PISA 2009 data.",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# ---------------------------------------------------------
# CORS MIDDLEWARE CONFIGURATION
# ---------------------------------------------------------
# RATIONALE & SECURITY REASONING:
# 1. allow_origins: Avoid using "*" (wildcard) in production-ready apps.
#    Using a wildcard allows any arbitrary third-party site to send cross-origin requests,
#    which leaves the application vulnerable to Cross-Origin Resource Sharing (CORS) exploits
#    and potentially unauthorized usage of the model and training datasets.
# 2. Localhost Origins: Explicitly listing localhost ports (80, 3000, 5000) and loopback addresses
#    is appropriate for secure development, ensuring developers can run integration tests
#    from local development servers (e.g. Flutter Web, React, or standard proxy environments)
#    without opening the API to the public internet.
# 3. allow_credentials: Required for supporting local secure cookies, state sessions, or tokens.
# 4. allow_methods: Explicitly restricted to GET and POST as required by our endpoints, blocking
#    harmful requests like DELETE or PUT.
# 5. allow_headers: Set to ["*"] to allow custom headers (e.g. Content-Type, Authorization) during local development.
origins = [
    "http://localhost",
    "http://localhost:3000",
    "http://localhost:5000",
    "http://127.0.0.1",
    "http://127.0.0.1:3000",
    "http://127.0.0.1:5000",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

# Define file paths for the ML artifacts
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(BASE_DIR, "best_model.joblib")
PREPROCESSOR_PATH = os.path.join(BASE_DIR, "preprocessor.joblib")

# Global variables for model and preprocessor
model = None
preprocessor = None

def load_ml_artifacts() -> None:
    """
    Loads the trained model and preprocessor joblib files once on startup.
    Raises FileNotFoundError if artifacts are missing.
    """
    global model, preprocessor
    if not os.path.exists(MODEL_PATH) or not os.path.exists(PREPROCESSOR_PATH):
        raise FileNotFoundError(
            f"Required ML artifacts not found in {BASE_DIR}. "
            f"Ensure best_model.joblib and preprocessor.joblib are present."
        )
    model = joblib.load(MODEL_PATH)
    preprocessor = joblib.load(PREPROCESSOR_PATH)

# Load once during application startup
@app.on_event("startup")
def startup_event():
    try:
        load_ml_artifacts()
        print("ML Model and Preprocessor loaded successfully.")
    except Exception as e:
        print(f"Startup warning - artifacts not loaded: {str(e)}")

def ensure_artifacts_loaded() -> None:
    """
    Ensures model and preprocessor are loaded before serving prediction/retrain requests.
    Attempts to load them if they are not already cached.
    """
    global model, preprocessor
    if model is None or preprocessor is None:
        try:
            load_ml_artifacts()
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Model files not available on the server. Please run training first. Error: {str(e)}"
            )

# ---------------------------------------------------------
# PYDANTIC MODEL SCHEMAS WITH CONSTRAINTS
# ---------------------------------------------------------
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
        description="Weekly instruction minutes in English class. Realistic range: 0 to 3000.",
        json_schema_extra={"example": 250.0}
    )
    studentsInEnglish: float = Field(
        ..., 
        ge=0.0, 
        le=100.0, 
        description="Number of students in English class. Realistic range: 0 to 100.",
        json_schema_extra={"example": 25.0}
    )
    schoolSize: float = Field(
        ..., 
        ge=0.0, 
        le=10000.0, 
        description="Total student enrollment at school. Realistic range: 0 to 10000.",
        json_schema_extra={"example": 1200.0}
    )

class PredictionOutput(BaseModel):
    predicted_reading_score: float
    model: str
    status: str

class RetrainItem(PredictionInput):
    readingScore: float = Field(
        ..., 
        ge=0.0, 
        le=1000.0, 
        description="Actual reading score of the student to append for retraining. Range: 0 to 1000.",
        json_schema_extra={"example": 540.2}
    )

# ---------------------------------------------------------
# EXCEPTION HANDLERS
# ---------------------------------------------------------
@app.exception_handler(Exception)
def global_exception_handler(request: Request, exc: Exception):
    """
    Global exception handler to capture unexpected errors and prevent API crashes.
    """
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "status": "error",
            "type": "ServerError",
            "message": "An unexpected server error occurred.",
            "detail": str(exc)
        }
    )

# ---------------------------------------------------------
# ENDPOINTS
# ---------------------------------------------------------
@app.get("/")
def read_root():
    """
    Root health check endpoint.
    """
    return {
        "status": "online",
        "service": "Student Reading Score Predictor API",
        "documentation": "/docs"
    }

@app.post("/predict", response_model=PredictionOutput)
def predict(data: PredictionInput):
    """
    Predicts the reading score of a student using the 8 selected PISA 2009 features.
    """
    ensure_artifacts_loaded()
    
    # Construct input DataFrame layout matching training layout
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
        # Preprocess input data point using loaded pipeline
        X_preprocessed = preprocessor.transform(df)
        
        # Predict using loaded model
        predicted_score = model.predict(X_preprocessed)[0]
        
        # Return structured JSON converting numpy types to native Python floats
        return PredictionOutput(
            predicted_reading_score=float(predicted_score),
            model="Random Forest Regressor",
            status="success"
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Inference pipeline execution failure: {str(e)}"
        )

@app.post("/retrain")
def retrain_model(new_data: List[RetrainItem]):
    """
    Retrains the Random Forest Regressor on the original dataset appended with new observations.
    Overwrites the saved joblib files and updates the active model instance.
    """
    global model, preprocessor
    ensure_artifacts_loaded()
    
    if not new_data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Retraining requires a non-empty list of new observations."
        )
        
    try:
        # Resolve data paths relative to the API directory
        train_csv_path = os.path.abspath(os.path.join(BASE_DIR, "..", "linear_regression", "data", "pisa2009train.csv"))
        test_csv_path = os.path.abspath(os.path.join(BASE_DIR, "..", "linear_regression", "data", "pisa2009test.csv"))
        
        if not os.path.exists(train_csv_path) or not os.path.exists(test_csv_path):
            raise FileNotFoundError(
                f"PISA 2009 datasets not found. "
                f"Expected locations: {train_csv_path} and {test_csv_path}"
            )
            
        # Load existing training dataset
        df_train = pd.read_csv(train_csv_path)
        df_test = pd.read_csv(test_csv_path)
        
        # Construct DataFrame for new data records
        new_records = []
        for item in new_data:
            new_records.append({
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
        new_df = pd.DataFrame(new_records)
        
        # Align columns by filling missing features with NaN to respect CSV schema structure
        for col in df_train.columns:
            if col not in new_df.columns:
                new_df[col] = np.nan
        
        # Reorder columns to match the training CSV column order exactly
        new_df = new_df[df_train.columns]
        
        # Append and save back to the training CSV
        df_train_updated = pd.concat([df_train, new_df], ignore_index=True)
        df_train_updated.to_csv(train_csv_path, index=False)
        
        # Reload and filter rows with missing target variable readingScore
        df_train_clean = df_train_updated.dropna(subset=['readingScore'])
        df_test_clean = df_test.dropna(subset=['readingScore'])
        
        # Select active features and target
        features = ['grade', 'male', 'raceeth', 'expectBachelors', 'read30MinsADay', 
                    'minutesPerWeekEnglish', 'studentsInEnglish', 'schoolSize']
        target = 'readingScore'
        
        X_train_new = df_train_clean[features]
        y_train_new = df_train_clean[target]
        X_test_new = df_test_clean[features]
        y_test_new = df_test_clean[target]
        
        # Refit preprocessor on the expanded dataset to prevent any preprocessing drift
        X_train_prep = preprocessor.fit_transform(X_train_new)
        X_test_prep = preprocessor.transform(X_test_new)
        
        # Fit model using the same hyperparameters as in Task 1 for parity
        retrained_model = RandomForestRegressor(n_estimators=150, max_depth=8, random_state=42)
        retrained_model.fit(X_train_prep, y_train_new)
        
        # Overwrite the joblib files
        joblib.dump(retrained_model, MODEL_PATH)
        joblib.dump(preprocessor, PREPROCESSOR_PATH)
        
        # Update local runtime models
        model = retrained_model
        
        # Evaluate model metrics on test set
        y_pred = model.predict(X_test_prep)
        new_rmse = root_mean_squared_error(y_test_new, y_pred)
        new_r2 = r2_score(y_test_new, y_pred)
        
        return {
            "message": "training completed",
            "new_RMSE": float(new_rmse),
            "new_R2": float(new_r2),
            "number_of_samples": int(len(df_train_clean))
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Retraining execution failure: {str(e)}"
        )
