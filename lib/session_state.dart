library session_state;

// Global variable to track if the video has been suppressed for the current session.
// This resets to false when the app is restarted.
bool hasVideoPlayedThisSession = false;
