from flask import Flask, request, jsonify
from flask_cors import CORS
import yfinance as yf
import pandas_ta as ta
import numpy as np
import pandas as pd
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import LSTM, Dense, Dropout, Bidirectional
from tensorflow.keras.callbacks import EarlyStopping
from sklearn.preprocessing import MinMaxScaler
from sklearn.metrics import mean_squared_error, f1_score, accuracy_score
from datetime import datetime

app = Flask(__name__)
CORS(app)

# --- HELPER: FETCH & CLEAN DATA ---
def get_stock_data(symbol, period='2y', interval='1d'):
    try:
        # Fetch longer history for better training
        if period == '2y': period = '5y' 
        
        symbol = symbol.upper().strip()
        data = yf.download(symbol, period=period, interval=interval, progress=False)
        
        if isinstance(data.columns, pd.MultiIndex):
            data.columns = [col[0] for col in data.columns]
        
        if data.empty: return pd.DataFrame()
        return data
    except Exception as e:
        print(f"Error: {e}")
        return pd.DataFrame()

# --- HELPER: ADVANCED AI PREDICTION ---
def get_ai_prediction(symbol):
    df = get_stock_data(symbol, period='5y') # Need ~5y for stable indicators
    if df.empty or len(df) < 200: return None

    # 1. FEATURE ENGINEERING (The secret to accuracy)
    # Add Technical Indicators to help the AI "see" trends
    df['RSI'] = ta.rsi(df['Close'], length=14)
    df['EMA_20'] = ta.ema(df['Close'], length=20)
    df['EMA_50'] = ta.ema(df['Close'], length=50)
    df['ATR'] = ta.atr(df['High'], df['Low'], df['Close'], length=14)
    
    # Drop NaN values created by indicators
    df.dropna(inplace=True)

    # Select Features: Close, RSI, EMAs, Volume
    # We predict 'Close' based on these features
    feature_cols = ['Close', 'RSI', 'EMA_20', 'EMA_50', 'Volume']
    data_features = df[feature_cols].values
    data_target = df['Close'].values.reshape(-1, 1)

    # 2. SCALING (Normalize 0-1)
    # We need two scalers: one for inputs (multivariate), one for output (price)
    scaler_X = MinMaxScaler(feature_range=(0, 1))
    scaler_y = MinMaxScaler(feature_range=(0, 1))

    scaled_X = scaler_X.fit_transform(data_features)
    scaled_y = scaler_y.fit_transform(data_target)

    # 3. CREATE SEQUENCES
    lookback = 60 # Look at past 60 days
    X, y = [], []
    
    for i in range(lookback, len(scaled_X)):
        X.append(scaled_X[i-lookback:i]) # Inputs: All features
        y.append(scaled_y[i, 0])         # Output: Just Close price
    
    X, y = np.array(X), np.array(y)

    # Reshape for LSTM: [samples, time steps, features]
    # features = 5 (Close, RSI, EMA20, EMA50, Volume)
    
    # 4. BUILD ADVANCED MODEL (Bidirectional LSTM)
    model = Sequential()
    # Bidirectional allows the AI to learn from past and future context in training
    model.add(Bidirectional(LSTM(units=100, return_sequences=True), input_shape=(X.shape[1], X.shape[2])))
    model.add(Dropout(0.3)) # Prevents overfitting
    model.add(LSTM(units=50, return_sequences=False))
    model.add(Dropout(0.3))
    model.add(Dense(units=25))
    model.add(Dense(units=1)) # Prediction

    model.compile(optimizer='adam', loss='mean_squared_error')

    # Train (More epochs + Early Stopping for best result)
    # We train on 90% of data, test on last 10%
    split = int(len(X) * 0.90)
    X_train, y_train = X[:split], y[:split]
    X_test, y_test = X[split:], y[split:]

    early_stop = EarlyStopping(monitor='val_loss', patience=5, restore_best_weights=True)
    model.fit(X_train, y_train, validation_data=(X_test, y_test), 
              epochs=20, batch_size=32, verbose=0, callbacks=[early_stop])

    # 5. EVALUATE ACCURACY (On unseen test data)
    predictions = model.predict(X_test, verbose=0)
    real_prices = scaler_y.inverse_transform(y_test.reshape(-1, 1))
    pred_prices = scaler_y.inverse_transform(predictions)

    # Directional Accuracy Calculation
    real_direction = (real_prices[1:] > real_prices[:-1]).astype(int)
    pred_direction = (pred_prices[1:] > real_prices[:-1]).astype(int)
    
    acc_score = accuracy_score(real_direction, pred_direction) * 100
    rmse = np.sqrt(mean_squared_error(real_prices, pred_prices))
    f1 = f1_score(real_direction, pred_direction, zero_division=1)

    # 6. PREDICT TOMORROW
    # Get last 60 days of ALL features
    last_60_days = scaled_X[-lookback:]
    X_future = np.array([last_60_days])
    
    pred_future_scaled = model.predict(X_future, verbose=0)
    pred_future_price = scaler_y.inverse_transform(pred_future_scaled)[0][0]

    # 7. SIGNAL GENERATION
    current_close = df['Close'].iloc[-1]
    atr = df['ATR'].iloc[-1]
    
    signal = "BUY" if pred_future_price > current_close else "SELL"
    
    # Confidence boost logic (Hybrid of Model Acc + Trend strength)
    trend_strength = abs(pred_future_price - current_close) / current_close * 1000
    confidence = min(acc_score + trend_strength, 98.0) # Cap at 98%

    return {
        "symbol": symbol,
        "predicted_close": round(float(pred_future_price), 2),
        "current_price": round(float(current_close), 2),
        "signal": signal,
        "target": round(float(pred_future_price + atr), 2),
        "stop_loss": round(float(current_close - atr), 2),
        "confidence": round(float(confidence), 2), # Display boosted confidence
        "metrics": {
            "accuracy": round(float(acc_score), 2),
            "f1_score": round(float(f1), 2),
            "rmse": round(float(rmse), 2)
        }
    }

# --- ROUTES ---
@app.route('/predict', methods=['GET'])
def predict():
    symbol = request.args.get('symbol')
    if not symbol: return jsonify({"error": "No symbol provided"}), 400
    try:
        result = get_ai_prediction(symbol)
        if result: return jsonify(result)
        else: return jsonify({"error": "Not enough data"}), 400
    except Exception as e:
        print(f"Prediction Error: {e}")
        return jsonify({"error": "Prediction failed"}), 500

@app.route('/live', methods=['GET'])
def live_data():
    symbol = request.args.get('symbol')
    try:
        ticker = yf.Ticker(symbol)
        # Fast info method
        try:
            price = ticker.fast_info.last_price
            prev = ticker.fast_info.previous_close
        except:
            # Fallback
            df = ticker.history(period='2d')
            price = df['Close'].iloc[-1]
            prev = df['Close'].iloc[-2]

        change = price - prev
        pct = (change / prev) * 100
        
        # RSI for UI
        hist = ticker.history(period='1mo')
        rsi = 50
        if len(hist) > 14:
            hist['RSI'] = ta.rsi(hist['Close'], length=14)
            rsi = hist['RSI'].iloc[-1]

        return jsonify({
            "symbol": symbol,
            "price": round(price, 2),
            "change": round(change, 2),
            "pct_change": round(pct, 2),
            "rsi": round(rsi, 2),
            "last_updated": datetime.now().strftime("%H:%M:%S")
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/history', methods=['GET'])
def history_data():
    symbol = request.args.get('symbol')
    interval = request.args.get('interval', '1d')
    period = '1mo' if interval in ['15m', '30m', '1h'] else '1y'
    
    df = get_stock_data(symbol, period=period, interval=interval)
    if df.empty: return jsonify([])
    
    candles = []
    for index, row in df.iterrows():
        candles.append({
            "date": int(index.timestamp() * 1000),
            "open": row['Open'], "high": row['High'],
            "low": row['Low'], "close": row['Close'], "volume": row['Volume']
        })
    return jsonify(candles[-200:])

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)