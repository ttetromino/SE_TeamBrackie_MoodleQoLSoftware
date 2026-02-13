## Architectural Style: Hybrid Client-Side Architecture
The system utilizes a **Client-Server** foundation but operates primarily as a Thick Client / Edge-heavy architecture. 

* **Logic Location**: Most operations, including GWA computation, AI-driven analysis, and task management, are handled within the user’s browser extension or mobile application. These processes run locally inside the app environment rather than on external servers.
* **Data Strategy**: It uses an “Offline-First” caching system, where the browser’s database serves as a local data store. This approach helps reduce server load on the UPHSL Moodle infrastructure.
* **Bridge Pattern**: The Web Extension serves as an exclusive "bridge" to scrape and fetch data from the Moodle domain to bypass CORS limitations.

## High-Level Architecture Diagram
The following diagram illustrates the interaction between the Moodle+ components and the existing UPHSL Moodle infrastructure.

![alt text](https://github.com/ttetromino/SE_TeamBrackie_MoodleQoLSoftware/blob/b678dba1763480a00820ca275ea423c3de119e30/docs/architecture/DIAGRAM.png)

### Major Components & Data Flow:
* **Moodle+ Web Extension/App**: The primary interface where users interact with the Dashboard and Task Management tools.
* **The Bridge (Data Scraper)**: Extracts academic records and deadlines from the official Moodle site using flexible CSS selectors.
* **Local Storage**: Stores encrypted student records and course content locally to ensure privacy and offline access.
* **Data Flow**: Moodle Server > Web Extension (Bridge) > Local Cache > Website Application > UI Components.

## Design Principles Applied
1. *Separation of Concerns (SoC)*

The team has strictly separated the Data Acquisition layer from the Presentation layer. By using the Web Extension as an exclusive bridge for fetching data, the core productivity features (like the GWA calculator and Task Manager) remain independent of the Moodle server's unstable connectivity. This ensures that even if the Moodle site is slow, the user's local productivity dashboard remains functional.

2. *Security by Design (Local-Only Policy)*

To address the risk of credential theft, the architecture applies a strict "Local-Only" data principle.

* No External Database: Unlike traditional web apps, this system does not maintain a centralized database for student data.
* Encryption: All sensitive academic records are encrypted and stored solely within the user's browser environment. This minimizes the attack surface and ensures compliance with the Philippine Data Privacy Act (RA10173).

