# DjangoQuest Game Client

This is the 2D top-down educational RPG game client for DjangoQuest, built in the Godot Engine. It connects to the DjangoQuest backend for real-time cloud saves, authentication, platform announcements, controlled coding challenge validation, and AI-assisted feedback.

Judge0 is no longer part of the active game workflow. Coding challenges use local Godot checks plus the Django backend's controlled validation and AI support.

## How the Projects Connect
This platform has three main parts that work together:
1. **Godot Game Client (This Repository)**: The actual 2D top-down RPG game.
2. **[Backend Server](https://github.com/7uisu/DjangoQuest-Backend.git)**: The core API and database bridge. The game talks to this to log you in, save progress, check code, and fetch platform records.
3. **[Frontend Website](https://github.com/7uisu/DjangoQuest-Frontend.git)**: The website where teachers can see their students' game progress.

## Prerequisites
- **Godot Engine 4.x** (Download from [https://godotengine.org/](https://godotengine.org/))
- The [DjangoQuest Backend](../DjangoQuest-Backend) must be running at `http://localhost:8000/`. The game relies on this for logging in, saving progress, and fetching dialogue/achievements.

## Getting Started

1. **Clone the repository**
   You can clone via SSH or HTTPS:
   ```bash
   git clone git@github.com:7uisu/djangoquest_capstone_godot_project_revision.git
   cd djangoquest_capstone_godot_project_revision
   ```

2. **Open the Project in Godot**
   - Open Godot Engine.
   - Click the **"Import"** button.
   - Browse to the folder where you cloned the repository.
   - Select the `project.godot` file and click **"Import & Edit"**.

3. **Verify API Connections (Optional)**
   The core configuration for connecting to the web server is in `Scripts/Autoload or Global/api_manager.gd`. The default `BASE_URL` is configured to point to `http://127.0.0.1:8000`.

4. **Run the Game**
   - In the top-right corner of the Godot editor, click the **"Play"** button (or press `F5` / `Cmd+B`).
   - The game window will launch!
   - You can log in using an account created via your local web dashboard, or click **"Play as Guest"** to try it without an account.
