#!/bin/bash

# ---------------------------------------------------------
# Techcrush Cloud Solutions - Automated Website Deployment
# Author: Olayinka Oyero
# Date: $(date)
# ---------------------------------------------------------

set -e

WEB_ROOT="/var/www/html"
ASSETS_DIR="$WEB_ROOT/assets"
IMG_DIR="$ASSETS_DIR/images"

echo "🌐 Starting automated web server and website setup..."

# ---------------------------------------------------------
# Step 1 — Update system
# ---------------------------------------------------------
if [ -f /etc/debian_version ]; then
  echo "🔄 Updating Ubuntu/Debian system..."
  sudo apt update -y && sudo apt upgrade -y
elif [ -f /etc/amazon-linux-release ]; then
  echo "🔄 Updating Amazon Linux system..."
  sudo yum update -y
else
  echo "⚠️ Unknown OS — update manually."
fi

# ---------------------------------------------------------
# Step 2 — Check and install NGINX if missing
# ---------------------------------------------------------
if ! command -v nginx &> /dev/null; then
  echo "📦 NGINX not found. Installing now..."
  if [ -f /etc/debian_version ]; then
    sudo apt install nginx -y
  elif [ -f /etc/amazon-linux-release ]; then
    sudo amazon-linux-extras install nginx1 -y
  else
    echo "❌ Unsupported OS. Please install NGINX manually."
    exit 1
  fi
else
  echo "✅ NGINX is already installed."
fi

# Start and enable NGINX
sudo systemctl start nginx
sudo systemctl enable nginx
echo "🚀 NGINX is running and enabled."

# ---------------------------------------------------------
# Step 3 — Create website structure
# ---------------------------------------------------------
sudo mkdir -p $IMG_DIR
sudo chown -R $USER:$USER /var/www/html
echo "✅ Directory structure created."

# ---------------------------------------------------------
# Step 4 — Create website files
# ---------------------------------------------------------
cat <<'EOF' | sudo tee $WEB_ROOT/index.html > /dev/null
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Techcrush Cloud Solutions</title>
  <link rel="stylesheet" href="assets/style.css">
  <script src="assets/script.js" defer></script>
</head>
<body>
  <header>
    <div class="container nav">
      <img src="assets/images/logo.png" alt="Techcrush Logo" class="logo">
      <nav>
        <ul>
          <li><a href="index.html" class="active">Home</a></li>
          <li><a href="about.html">About</a></li>
          <li><a href="contact.html">Contact</a></li>
        </ul>
      </nav>
    </div>
  </header>

  <section class="hero">
    <div class="hero-content">
      <h1>Empowering the Cloud Generation ☁️</h1>
      <p>We build secure, scalable, and modern cloud infrastructures that power innovation.</p>
      <a href="about.html" class="btn">Learn More</a>
    </div>
  </section>

  <section class="features">
    <div class="container">
      <h2>Our Core Services</h2>
      <div class="grid">
        <div class="card">
          <h3>☁️ Cloud Infrastructure</h3>
          <p>We design and deploy reliable cloud environments using AWS, Azure, and GCP.</p>
        </div>
        <div class="card">
          <h3>🔒 Cybersecurity</h3>
          <p>We ensure data integrity and compliance through layered defense strategies.</p>
        </div>
        <div class="card">
          <h3>⚙️ DevOps & Automation</h3>
          <p>We accelerate development and deployment through continuous integration pipelines.</p>
        </div>
      </div>
    </div>
  </section>

  <footer>
    <p>© 2025 Techcrush Cloud Solutions | Built by Olayinka Oyero 🚀</p>
  </footer>
</body>
</html>
EOF

# About Page
cat <<'EOF' | sudo tee $WEB_ROOT/about.html > /dev/null
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>About - Techcrush Cloud Solutions</title>
  <link rel="stylesheet" href="assets/style.css">
</head>
<body>
  <header>
    <div class="container nav">
      <img src="assets/images/logo.png" alt="Techcrush Logo" class="logo">
      <nav>
        <ul>
          <li><a href="index.html">Home</a></li>
          <li><a href="about.html" class="active">About</a></li>
          <li><a href="contact.html">Contact</a></li>
        </ul>
      </nav>
    </div>
  </header>

  <section class="about">
    <div class="container">
      <h1>About Us</h1>
      <p>Techcrush Cloud Solutions is a trusted provider of cloud computing, cybersecurity, and DevOps automation. We empower individuals, businesses, and institutions to leverage technology for growth and efficiency.</p>
      <p>Founded by <strong>Olayinka Oyero</strong>, we combine technical excellence with a deep understanding of cloud ecosystems to deliver results that matter.</p>
    </div>
  </section>

  <footer>
    <p>© 2025 Techcrush Cloud Solutions</p>
  </footer>
</body>
</html>
EOF

# Contact Page
cat <<'EOF' | sudo tee $WEB_ROOT/contact.html > /dev/null
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Contact - Techcrush Cloud Solutions</title>
  <link rel="stylesheet" href="assets/style.css">
</head>
<body>
  <header>
    <div class="container nav">
      <img src="assets/images/logo.png" alt="Techcrush Logo" class="logo">
      <nav>
        <ul>
          <li><a href="index.html">Home</a></li>
          <li><a href="about.html">About</a></li>
          <li><a href="contact.html" class="active">Contact</a></li>
        </ul>
      </nav>
    </div>
  </header>

  <section class="contact">
    <div class="container">
      <h1>Contact Us</h1>
      <p>We’d love to hear from you! Reach out for partnerships, inquiries, or support.</p>
      <form>
        <input type="text" placeholder="Your Name" required>
        <input type="email" placeholder="Your Email" required>
        <textarea placeholder="Your Message" rows="5"></textarea>
        <button type="submit" class="btn">Send Message</button>
      </form>
    </div>
  </section>

  <footer>
    <p>© 2025 Techcrush Cloud Solutions</p>
  </footer>
</body>
</html>
EOF

# CSS
cat <<'EOF' | sudo tee $ASSETS_DIR/style.css > /dev/null
/* --- Techcrush Cloud Solutions CSS --- */
* { margin: 0; padding: 0; box-sizing: border-box; }
body {
  font-family: "Segoe UI", Arial, sans-serif;
  color: #333;
  background-color: #f8fafc;
}
.container { width: 90%; max-width: 1100px; margin: 0 auto; }
header { background: #0a2540; color: white; padding: 15px 0; }
.nav { display: flex; justify-content: space-between; align-items: center; }
.logo { width: 120px; }
nav ul { display: flex; list-style: none; gap: 20px; }
nav a { color: white; text-decoration: none; font-weight: 500; }
nav a.active, nav a:hover { color: #00b4d8; }
.hero { background: #0a2540; color: white; text-align: center; padding: 100px 20px; }
.hero-content h1 { font-size: 2.8em; margin-bottom: 15px; }
.btn {
  background: #00b4d8; color: white; padding: 10px 25px;
  border: none; border-radius: 5px; text-decoration: none;
  font-weight: 600; transition: 0.3s;
}
.btn:hover { background: #0096c7; }
.features { background: white; padding: 60px 20px; text-align: center; }
.features h2 { margin-bottom: 30px; color: #0a2540; }
.grid { display: flex; flex-wrap: wrap; justify-content: center; gap: 25px; }
.card {
  background: #f1f5f9; border-radius: 10px; padding: 20px;
  width: 300px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}
.card h3 { color: #0078d7; margin-bottom: 10px; }
form {
  display: flex; flex-direction: column; gap: 15px;
  max-width: 500px; margin: 30px auto;
}
input, textarea {
  padding: 10px; border: 1px solid #ccc; border-radius: 5px;
}
footer {
  background: #0a2540; color: white; text-align: center;
  padding: 15px 0; margin-top: 50px;
}
EOF

# JS
cat <<'EOF' | sudo tee $ASSETS_DIR/script.js > /dev/null
document.addEventListener("DOMContentLoaded", () => {
  console.log("🌐 Techcrush Cloud Site Loaded Successfully!");
});
EOF

# ---------------------------------------------------------
# Step 5 — Permissions and restart NGINX
# ---------------------------------------------------------
sudo chmod -R 755 /var/www/html
sudo systemctl restart nginx

echo "✅ Deployment completed successfully!"
echo "🌍 Visit your website at: http://$(curl -s ifconfig.me)"

