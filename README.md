# DjangoQuest Game Client

This is the 3D educational game client for DjangoQuest, built in the Godot Engine. It connects to the DjangoQuest backend for real-time cloud saves, authentication, and platform announcements.

## Prerequisites
- **Godot Engine 4.x** (Download from [https://godotengine.org/](https://godotengine.org/))
- The [DjangoQuest Backend](../DjangoQuest-Backend) must be running at `http://localhost:8000/`. The game relies on this for logging in, saving progress, and fetching dialogue/achievements.

## Getting Started

1. **Clone the repository**
   ```bash
   git clone <repository_url>
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
