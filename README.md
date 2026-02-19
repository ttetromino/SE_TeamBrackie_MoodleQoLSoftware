# MoodlePlus
**Moodle+** is a web extension and application to enhance the productivity and well-being of students. It addresses Moodle LMS limitations such as slow server response and lack of integrated planning tools.

## Features of the Program
**1. Account Creation**: The program will allow for new users to create their account, which is used to save limited data.
**2. Account / Credentials Editing**: The program will allow for users to edit their credentials (emails, passwords).
**3. Course Enrollment**: This feature will allow users to enroll into courses on their own.
**4. Adding Course Items**: This feature allows users to add their own course items for easier and more accessible tracking.
**5. Dashboard**: This is for easier navigation and access to information such as different enrolled subjects.


## Architectural Style: Hybrid Client-Side Architecture
The system utilizes a **Client-Server** foundation but operates primarily as a Thick Client / Edge-heavy architecture.

* **Offline-First Strategy**: Uses an intelligent cashing mechanism to reduce HTTP requests to servers. 
* **Logic Location**: Most operations, including GWA computation, AI-driven analysis, and task management, are handled within the user’s browser extension or mobile application. These processes run locally inside the app environment rather than on external servers.
* **Data Strategy**: It uses an “Offline-First” caching system, where the browser’s database serves as a local data store. This approach helps reduce server load on the UPHSL Moodle infrastructure.
* **Bridge Pattern**: The Web Extension serves as an exclusive "bridge" to scrape and fetch data from the Moodle domain to bypass CORS limitations.

## High-Level Architecture Diagram
The following diagram illustrates the interaction between the Moodle+ components and the existing UPHSL Moodle infrastructure.

![alt text](https://github.com/ttetromino/SE_TeamBrackie_MoodleQoLSoftware/blob/main/docs/architecture/DIAGRAM.png)

### Major Components & Data Flow:
* **Moodle+ Web Extension/App**: The primary interface where users interact with the Dashboard and Task Management tools.
* **The Bridge (Data Scraper)**: Extracts academic records and deadlines from the official Moodle site using flexible CSS selectors.
* **Local Storage**: Stores encrypted student records and course content locally to ensure privacy and offline access.
* **UI/UX Layer**: A dashboard providing shortcuts to task management and performance analysis. 
* **Data Flow**: Moodle Server > Web Extension (Bridge) > Local Cache > Website Application > UI Components.

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
