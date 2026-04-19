
// Store user sessions in memory
const userSessions = new Map();

// Cleanup expired sessions (run every hour)
const startSessionCleanup = () => {
  setInterval(() => {
    const oneHour = 3600000;
    const now = Date.now();
    let removedCount = 0;
    
    for (const [id, session] of userSessions.entries()) {
      if (now - session.timestamp > oneHour) {
        userSessions.delete(id);
        removedCount++;
      }
    }
    
    if (removedCount > 0) {
      console.log(`🧹 Removed ${removedCount} expired sessions`);
    }
  }, 3600000);
};

module.exports = {
  userSessions,
  startSessionCleanup
};
