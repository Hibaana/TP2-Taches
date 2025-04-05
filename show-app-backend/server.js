require('dotenv').config();
const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const showRoutes = require('./routes/shows');

const app = express();
const PORT = process.env.PORT || 5000;
// Configuration de la base de données
const db = new sqlite3.Database('./database.db', (err) => {
  if (err) {
    console.error('Erreur de connexion à la base de données:', err.message);
  } else {
    console.log('Connecté à la base de données SQLite');
    db.run(`CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT UNIQUE NOT NULL,
      password TEXT NOT NULL
    )`);
  }
});

app.use(cors(
  ));
app.use(bodyParser.json());
app.use('/uploads', express.static('uploads'));
app.use('/shows', showRoutes);

app.listen(5000, '0.0.0.0', () => {
    console.log('Server running on http://0.0.0.0:5000');
});