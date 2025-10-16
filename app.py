import pickle
import joblib
import pandas as pd
from fastapi import FastAPI
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
import os

# Load the pre-trained model
model = joblib.load("models/model.pkl")

# Create FastAPI app
app = FastAPI(title="Car Price Prediction API", version="1.0.0")

# Health check endpoint
@app.get("/health")
def health_check():
    return {"status": "healthy"}

# Model metadata endpoint
@app.get("/metadata")
def get_metadata():
    return {
        "model_info": "Car Price Prediction Model",
        "model": "model.pkl",
        "version": "1.0.0",
        "features": [
            "manufacturer", "model", "engine_size", "fuel_type", 
            "year_of_manufacture", "mileage"
        ]
    }

# Prediction endpoint
@app.post("/predict")
def predict_car_price(payload_dict: dict):
    # Extract features from input dictionary
    manufacturer = str(payload_dict["Manufacturer"]).strip()
    model_name = str(payload_dict["Model"]).strip()
    fuel = str(payload_dict["Fuel type"]).strip()
    engine = float(payload_dict["Engine size"])
    year = int(payload_dict["Year of manufacture"])
    mileage = float(payload_dict["Mileage"])

    # Derived features (training pipeline expected these)
    CURRENT_YEAR = 2025
    age = max(CURRENT_YEAR - year, 0)
    mileage_per_year = mileage / max(age, 1)
    vintage = int(age >= 20)
    
    # Create single-row dataframe with ALL columns needed
    row = {
        "Manufacturer": manufacturer,
        "Model": model_name,
        "Fuel type": fuel,
        "Engine size": engine,
        "Year of manufacture": year,
        "Mileage": mileage,
        # derived:
        "age": age,
        "mileage_per_year": mileage_per_year,
        "vintage": vintage,
    }
    df = pd.DataFrame([row])
    
    # Make prediction
    prediction = model.predict(df)[0]
    
    # Return prediction
    return {
        "predicted_price_gbp": round(float(prediction),2)
    }

# Root endpoint
@app.get("/", response_class=HTMLResponse)
def read_root():
    html_path = os.path.join("templates", "index.html")
    with open(html_path, "r") as f:
        html_content = f.read()
    return HTMLResponse(content=html_content)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
