const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>HNG13 Stage 1</title>
      <style>
        body {
          font-family: Arial, sans-serif;
          display: flex;
          justify-content: center;
          align-items: center;
          height: 100vh;
          margin: 0;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          color: white;
        }
        .container {
          text-align: center;
          padding: 2rem;
          background: rgba(255, 255, 255, 0.1);
          border-radius: 10px;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>HNG13 Stage 1 DevOps Task</h1>
        <p>Name: Chuye Princely Tata</p>
        <p>Slack Username: @PrincelyT</p>
        <p>Application successfully deployed!</p>
        <p>Timestamp: ${new Date().toLocaleString()}</p>
      </div>
    </body>
    </html>
  `);
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
});
