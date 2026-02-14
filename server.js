const express = require('express');
const axios = require('axios');
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use(express.static('public'));

let priceHistory = [];
const MAX_HISTORY = 100;

async function fetchGoldPrice() {
  try {
    const response = await axios.get('https://api.metals.live/v1/spot/gold');
    const data = response.data;
    
    const priceData = {
      timestamp: Date.now(),
      price: data.price,
      currency: data.currency || 'USD',
      unit: data.unit || 'oz'
    };
    
    priceHistory.push(priceData);
    if (priceHistory.length > MAX_HISTORY) {
      priceHistory.shift();
    }
    
    return priceData;
  } catch (error) {
    console.error('Error fetching gold price:', error.message);
    return null;
  }
}

app.get('/api/gold-price', async (req, res) => {
  const priceData = await fetchGoldPrice();
  if (priceData) {
    res.json(priceData);
  } else {
    res.status(500).json({ error: 'Failed to fetch gold price' });
  }
});

app.get('/api/gold-history', (req, res) => {
  res.json(priceHistory);
});

app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
  fetchGoldPrice();
});