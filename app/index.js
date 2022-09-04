const chalk = require('chalk');
const debug = require('debug')('app');
const os = require('os');
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req,res) => {
  res.send('Hey, this is a test application');
});

app.listen(PORT, () => {
  
  console.log(`App is listening on http://${os.hostname}:${PORT}`);
});
