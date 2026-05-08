# MoodlePlus
**Moodle+** is a mobile application (APK) designed to enhance the Moodle LMS experience by providing task planning, offline access, and secure local data storage. It improves student productivity and addresses common Moodle limitations such as slow server response and lack of offline functionality.

## Objectives
- Improve Moodle usability and quality of life features  
- Enable offline access to previously loaded academic data  
- Ensure user data privacy through encrypted local storage  
- Follow clean architecture and proper documentation standards

## System Requirements

### Minimum Requirements
- Device: Android Smartphone  
- OS: Android 8.0 (Oreo) or higher  
- RAM: 3GB minimum  
- Storage: 150MB free space  

### Supported Platforms
- Android (APK Installation)

## Prerequisites
Before using Moodle+, you must have:
- An active **Moodle account** (e.g., UPHSL Moodle)  
- Internet connection (required for first-time login and data synchronization)

## Installation Guide (APK)

### Step 1: Download the APK
- Open the Google Drive link:  
  https://drive.google.com/file/d/1jtb6bDSBIH8yBBkZP60irOmozBmeJ0Pz/view  
- Tap **Download**  
- If a warning appears, tap **"Download anyway"**

### Step 2: Allow Installation from Unknown Sources
**Android blocks apps outside the Play Store by default.**

- Go to **Settings**  
- Navigate to:  
  **Apps → Special App Access → Install Unknown Apps**  
- Select the app you used to download the APK (e.g., Chrome or File Manager)  
- Enable **"Allow from this source"**

### Step 3: Install the APK
- Open your **Downloads** folder  
- Tap the downloaded `.apk` file  
- Tap **Install**  
- Wait for installation to complete  

### Step 4: Launch the App
- Tap **Open** after installation  
  OR  
- Find **Moodle+** in your app drawer  

### Important Notes
- Only install APK files from trusted sources  
- You may disable "Allow from this source" after installation for better security 

## How to Use the Program

### 1. Login
- Open the app  
- Enter your Moodle credentials  
- Complete authentication if required  

### 2. Dashboard
- View enrolled courses  
- Navigate through academic tools using the mobile interface  

### 3. Core Features
- **Gradebook** → View and track grades  
- **Calendar** → Monitor deadlines and schedules  
- **Backlog** → Manage tasks and requirements

## Visual Guide (Core Workflows)

### Login Screen
Shows user authentication using Moodle credentials.

<p align="center">
  <img src="https://github.com/ttetromino/SE_TeamBrackie_MoodleQoLSoftware/blob/main/src/business/pictures/Login.jpg" width="300"/>
</p>
---

### Sign Up Screen
Allows new users to create an account and initialize local storage.

<p align="center">
  <img src="https://github.com/ttetromino/SE_TeamBrackie_MoodleQoLSoftware/blob/main/src/business/pictures/Signup.jpg" width="300"/>
</p>
---

### Dashboard Overview
Displays enrolled courses and quick access to features.

<p align="center">
  <img src="https://github.com/ttetromino/SE_TeamBrackie_MoodleQoLSoftware/blob/main/src/business/pictures/Dashboard.jpg" width="300"/>
</p>

---

### Gradebook Navigation
Allows users to track grades and academic performance.

<p align="center">
  <img src="https://github.com/ttetromino/SE_TeamBrackie_MoodleQoLSoftware/blob/main/src/business/pictures/Gradebook.jpg" width="300"/>
</p>
---

### Calendar Usage
Displays schedules, deadlines, and upcoming activities.

<p align="center">
  <img src="https://github.com/ttetromino/SE_TeamBrackie_MoodleQoLSoftware/blob/main/src/business/pictures/Calendar.jpg" width="300"/>
</p>
---

### Backlog / Task Manager
Helps users organize pending academic tasks.

<p align="center">
  <img src="https://github.com/ttetromino/SE_TeamBrackie_MoodleQoLSoftware/blob/main/src/business/pictures/Backlog.jpg" width="300"/>
</p>

## Features of the Program
- **User Authentication** – Secure login using Moodle credentials  
- **Dashboard Interface** – Central hub for accessing all features  
- **Grade Tracking** – Monitor academic performance  
- **Calendar Integration** – View important deadlines  
- **Task Management (Backlog)** – Organize academic workload  
- **Offline Access** – Access cached data without internet  

## System Architecture
The system follows a **Hybrid Client-Side Architecture**, where most processing is done locally on the mobile device.

### Layered Architecture

#### 1. Presentation Layer
- Mobile UI (Dashboard, Courses, Files)  
- Handles user interaction  

#### 2. Application Controller Layer
- Auth Controller  
- Course Controller  
- File Controller  

**Responsibilities:**
- Process user actions  
- Manage application flow  

#### 3. Service Layer
- Auth Service  
- Moodle Service  
- Cache Service  

**Responsibilities:**
- Handle authentication  
- Fetch Moodle data  
- Manage caching  

#### 4. Data Layer
- Moodle API (Primary source)  
- Local Storage (Encrypted)  

**Responsibilities:**
- Store and retrieve data  
- Reduce API calls  

## System Flow
- UI → Controller → Service → Data Layer → Response → UI

## Authentication Flow
1. User launches the app  
2. User logs in using Moodle credentials  
3. Credentials are verified  
4. Authentication is completed  
5. User gains access to the app

## Data Flow (Fetching Courses)
1. User opens Courses  
2. Request sent to Controller  
3. Controller calls Moodle Service  
4. Data fetched from:
   - Moodle API (if online), or  
   - Local Storage (if cached)  
5. Data displayed  

## Architecture Diagram
![Architecture Diagram](https://github.com/ttetromino/SE_TeamBrackie_MoodleQoLSoftware/blob/main/docs/architecture/DIAGRAM.jpeg)

## Privacy & Security Model

Moodle+ follows a **Local-First Privacy Model**:

- **No External Database**  
  User credentials and academic data are NOT stored on remote servers  

- **Encrypted Local Storage**  
  Sensitive data is encrypted before being stored on the device  

- **No Third-Party Sharing**  
  The app does not transmit or share personal data externally  

- **User Data Control**  
  Users can clear app data anytime via device settings  

This design aligns with the **Philippine Data Privacy Act (RA 10173)**.

## FAQ / Troubleshooting

### App Not Installing
- Ensure "Install Unknown Apps" is enabled  
- Check if your Android version meets requirements  

### Login Failed
- Verify Moodle credentials  
- Check if Moodle server is accessible  

### Data Not Syncing
- Ensure stable internet connection  
- Restart the app and try again  

### Missing Courses or Data
- Make sure initial sync was completed  
- Try logging out and logging back in  

---

## Reporting Issues & Support

### Report a Bug
1. Go to the repository Issues page  
2. Click **New Issue**  
3. Provide:
   - Steps to reproduce  
   - Expected vs actual behavior  
   - Screenshots (if possible)  

### Submit Feedback
- Tag your issue as `enhancement`  

### Contact Support
- Use GitHub Discussions or Issues for communication  


## Design Principles Applied 1. 
*Separation of Concerns (SoC)* 

The team has strictly separated the Data Acquisition layer from the Presentation layer. By using the Web Extension as an exclusive bridge for fetching data, the core productivity features (like the GWA calculator and Task Manager) remain independent of the Moodle server's unstable connectivity. This ensures that even if the Moodle site is slow, the user's local productivity dashboard remains functional. 

2. *Security by Design (Local-Only Policy)*
3. To address the risk of credential theft, the architecture applies a strict "Local-Only" data principle.
*No External Database: Unlike traditional web apps, this system does not maintain a centralized database for student data.*

* Encryption: All sensitive academic records are encrypted and stored solely within the user's browser environment. This minimizes the attack surface and ensures compliance with the Philippine Data Privacy Act (RA10173).

## Development Status 
This project is currently under active development. Features and architecture may evolve as the project progresses. 

## Repository Structure The repository is organized to clearly separate source code, documentation, and configuration files: #### ├── docs/ Project documentation 
#### │ └─ architecture/ Architecture diagrams and explanations 
#### ├── src/ Source code 
#### ├── test/ Test files 
#### ├── .github/workflows/ CI/CD workflows 
#### ├── README.md Project overview 
#### └── LICENSE
