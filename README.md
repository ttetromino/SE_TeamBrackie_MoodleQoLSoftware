# MoodlePlus
**Moodle+** is a mobile application (APK) designed to enhance the Moodle LMS experience by providing task planning, offline access, and secure local data storage. It improves student productivity and addresses common Moodle limitations such as slow server response and lack of offline functionality.

## 📌 Objectives
- Improve Moodle usability and quality of life features  
- Enable offline access to previously loaded academic data  
- Ensure user data privacy through encrypted local storage  
- Follow clean architecture and proper documentation standards

## ⚙️ System Requirements

### Minimum Requirements
- Device: Android Smartphone  
- OS: Android 8.0 (Oreo) or higher  
- RAM: 3GB minimum  
- Storage: 150MB free space  

### Supported Platforms
- Android (APK Installation)  

## Features of the Program
* **Account Creation**: The program will allow for new users to create their account, which is used to save limited data.
* **Account / Credentials Editing**: The program will allow for users to edit their credentials (emails, passwords).
* **Dashboard**: This is for easier navigation and access to information such as different enrolled subjects.

## Roadmap
**Sprint 1**: System Kickoff
Duration: 2 Weeks
* Create System Architecture
* Backend Implementation
* Implement User Authentication (Log-in and Sign-Up)

**Sprint 2**: Data Acquisition
Duration: 2 Weeks
* Implement Data Scraping engine

**Sprint 3**: User Features & Management
Duration: 2 Weeks
* Implement Backlog list
* Implement Progress tracker
* Implement Profile editing functionality
* Implement Data Archive system

**Phase 2: Productivity & Governance**

**Sprint 4**: Academic Tools
Duration: 1 Week
* Implement Gradebook
* Implement Calendar integration

**Sprint 5:** Security & Administration
Duration: 2 Weeks
* Implement Notification system
* Implement Role-Based Access Control (RBAC)
* Implement Admin Dashboard for system oversight

**Phase 3: Finalization**

**Sprint 6**: Quality Assurance & Launch
Duration: 1 Week
* Polish User Experience (UI/UX refinements)
* Comprehensive User Documentation
* Production Deployment

## System Architecture
The system follows a **Hybrid Client-Side (Thick Client) Architecture** where most application logic runs on the user’s device through a browser extension or client application.

### MoodlePlus follows a **layered architecture design** to ensure separation of concerns, scalability, and maintainability. The system is divided into four main layers:
---
### 1. Presentation Layer
This layer represents the **Main App Interface**, where users interact with the system.

Features:
- Profile
- Courses
- LMS Files

Responsibilities:
- Display data to users
- Capture user input
- Send actions to the controller layer

---
### 2. Application Controller Layer

This layer handles the **core application logic** and acts as the middleman between the UI and services.

Components:
- Auth Controller
- Course Controller
- File Controller

Responsibilities:
- Process user actions
- Determine which services to call
- Maintain structured flow of requests

---
### 3. Service Layer

This layer is responsible for executing system operations.

Components:
- Auth Service
- Moodle Service
- Cache Service

Responsibilities:
- Handle authentication logic
- Fetch data from Moodle
- Manage caching for performance optimization

---
### 4. Data Layer

This is the lowest layer where data is stored and retrieved.

Components:
- Moodle API (Primary data source)
- Local Storage (IndexedDB)

Responsibilities:
- Provide course and file data
- Store cached data for faster access
- Reduce redundant API calls

---
##  System Flow
The system follows a structured data flow:

- The UI sends user actions to the Controller
- The Controller processes the request
- The Service Layer performs operations
- The Data Layer provides or stores data
- The response flows back to the UI

## Authentication Flow

1. User launches the app  
2. User selects Login or Sign Up  
3. Credentials are verified  
4. Two-Factor Authentication (2FA) is performed  
5. User gains access to the Main App Interface  

## Data Flow (Fetching Courses)

1. User opens the **Courses** section  
2. Request is sent to the **Course Controller**  
3. Controller calls the **Moodle Service**  
4. Moodle Service fetches data from:
   - Moodle API (if not cached), or
   - Local Storage (if available)  
5. Data is returned and displayed to the user
   
## High-Level Architecture Diagram
The following diagram illustrates the interaction between the Moodle+ components and the existing UPHSL Moodle infrastructure.

![alt text](https://github.com/ttetromino/SE_TeamBrackie_MoodleQoLSoftware/blob/main/docs/architecture/DIAGRAM.jpeg)

### Major Components & Data Flow:
* **Moodle+ Web Extension/App**: The primary interface where users interact with the Dashboard and Task Management tools.
* **The Bridge (Data Scraper)**: Extracts academic records from the official Moodle site using flexible CSS selectors.
* **Local Storage**: Stores encrypted student records and course content locally to ensure privacy and offline access.
* **UI/UX Layer**: A dashboard providing shortcuts to task management and performance analysis. 
* **Data Flow**: USER - UI (Main App Interface) - Controller - Service - Data (API/Cache)

### Non-Functional Requirements
* **Performance:** All computations such as analytics, and task prioritization are executed locally to ensure fast response times and minimal latency.
* **Reliability & Availability:** The offline-first design ensures that core features remain accessible even during Moodle downtime or unstable network connections.
* **Scalability:** Since the system does not rely on centralized servers, it scales naturally with the number of users without increasing infrastructure load.
* **Maintainability:** The modular architecture allows individual components (scraper, UI) to be updated independently.

### Security & Privacy
* **Local-Only Policy**: No external database is used for student credential or records.
* **Transparency**: A "Terms of Use" modal is required upon installation to ensure explicit data processing consent.
* **Performance**: Designed to run smoothly on low-end devices by offloading processing from the server to the client.

## Design Principles Applied
1. *Separation of Concerns (SoC)*

The team has strictly separated the Data Acquisition layer from the Presentation layer. By using the Web Extension as an exclusive bridge for fetching data, the core productivity features (like the GWA calculator and Task Manager) remain independent of the Moodle server's unstable connectivity. This ensures that even if the Moodle site is slow, the user's local productivity dashboard remains functional.

2. *Security by Design (Local-Only Policy)*

To address the risk of credential theft, the architecture applies a strict "Local-Only" data principle.

* No External Database: Unlike traditional web apps, this system does not maintain a centralized database for student data.
* Encryption: All sensitive academic records are encrypted and stored solely within the user's browser environment. This minimizes the attack surface and ensures compliance with the Philippine Data Privacy Act (RA10173).

## 🚀 Development Status
This project is currently under active development. Features and architecture may evolve as the project progresses.

## Repository Structure
The repository is organized to clearly separate source code, documentation, and configuration files:
#### ├── docs/ Project documentation
#### │ └── architecture/ Architecture diagrams and explanations
#### ├── src/ Source code
#### ├── test/ Test files
#### ├── .github/workflows/  CI/CD workflows
#### ├── README.md Project overview
#### └── LICENSE
