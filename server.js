const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.json({
    status: 'success',
    message: 'Hello from Docker Multi-stage Build!'
  });
});

app.listen(PORT, () => {
  console.log(`Production server listening on port ${PORT}`);
});
