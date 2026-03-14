# ⚡ phx-liveview-tutorial - Learn Phoenix LiveView Step-by-Step

[![Download Now](https://img.shields.io/badge/Download-phx--liveview--tutorial-brightgreen?style=for-the-badge)](https://github.com/ROCTORCITO/phx-liveview-tutorial)

---

## 📘 What is phx-liveview-tutorial?

This application is a simple and easy to follow Phoenix LiveView tutorial. It helps you learn how to use Phoenix LiveView, a tool that lets you build interactive web pages quickly. You won’t need to know much about programming to get started.

The guide covers basic concepts and shows you how to create your first live web app. It is designed to be clear and helpful, perfect for beginners.

---

## 💻 System Requirements

To run this tutorial on your Windows computer, make sure your system meets these requirements:

- Windows 10 or later (64-bit recommended)  
- At least 4 GB of RAM  
- At least 5 GB of free disk space  
- Internet connection for downloading files and updates  
- Administrator access for installing software  

You will also need to install some software tools, such as Elixir and Erlang, but the guide will help you through that step by step.

---

## 🚀 Getting Started

Before using the tutorial, you should prepare your environment.

1. Download the tutorial files from the main GitHub page.  
2. Install necessary software tools (Elixir, Erlang, and Node.js).  
3. Follow the step-by-step instructions to run the tutorial app on your computer.

We provide simple commands to enter into your Windows terminal, so no programming experience is required.

---

## ⬇️ How to Download and Install on Windows

You can visit this page to download all files:  
[Download phx-liveview-tutorial](https://github.com/ROCTORCITO/phx-liveview-tutorial)

Follow these steps carefully:

1. Click the green **Code** button on the GitHub page.  
2. Choose **Download ZIP** to get the complete tutorial files.  
3. Once downloaded, right-click the ZIP file and select **Extract All**.  
4. Choose a location you can easily find, like your Desktop or Documents folder.  

---

## ⚙️ Installing Necessary Software

The tutorial uses Phoenix LiveView, which runs on Elixir and Erlang. You will also need Node.js for managing web assets.

### Step 1: Install Erlang

- Visit https://www.erlang.org/downloads and download the latest Windows installer.  
- Run the installer and follow the instructions.  

### Step 2: Install Elixir

- Visit https://elixir-lang.org/install.html#windows and download the installer.  
- Run it and complete the setup.

### Step 3: Install Node.js

- Visit https://nodejs.org/en/download/ and choose the LTS version for Windows.  
- Run the installer and follow the instructions.  

After these installations, open a new terminal window and type the following commands to check if everything works:

```shell
erl -version
elixir -v
node -v
npm -v
```

If these commands show version numbers, your setup is correct.

---

## 🔧 Running the Tutorial Application

1. Open the folder where you extracted the tutorial files.  
2. Right-click inside that folder while holding the Shift key.  
3. Choose **Open PowerShell window here** or **Open command window here**.  
4. Run this command to install dependencies:

```shell
mix deps.get
```

5. Then, install JavaScript packages by running:

```shell
npm install --prefix assets
```

6. To start the application, use this command:

```shell
mix phx.server
```

7. Once the server runs, open your web browser and go to:

```
http://localhost:4000
```

You will see the tutorial web page with interactive examples.

---

## 🛠 How to Use the Tutorial

The web page guides you through building a LiveView app. You can type code directly and see live updates. This helps you learn how Phoenix LiveView works without needing extra software.

Explore different sections on the page. Each section explains a new concept and offers small exercises.

---

## 🔄 Updating the Tutorial Files

From time to time, updates may be available. To get the latest version:

1. Open the terminal inside your tutorial folder.  
2. Run the command:

```shell
git pull origin main
```

This command downloads the newest files if you previously cloned the repository using Git. If you downloaded the ZIP file, visit the GitHub page again and repeat the download steps.

---

## ❓ Troubleshooting Common Issues

- If `mix` commands do not work, make sure Elixir is installed and added to your system PATH.  
- If the server does not start, check if port 4000 is free or restart your computer.  
- If you get errors during `npm install`, ensure Node.js is installed and your internet connection is active.  
- If the browser does not load the tutorial, check the address is `http://localhost:4000` exactly.

---

## 🎯 Additional Resources

- Official Phoenix LiveView Docs: https://hexdocs.pm/phoenix_live_view  
- Elixir Getting Started Guide: https://elixir-lang.org/getting-started/introduction.html  
- Node.js Official Website: https://nodejs.org  

---

[![Download Now](https://img.shields.io/badge/Download-phx--liveview--tutorial-brightgreen?style=for-the-badge)](https://github.com/ROCTORCITO/phx-liveview-tutorial)