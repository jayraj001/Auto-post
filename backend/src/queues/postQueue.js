const Bull = require('bull');

const postQueue = new Bull('post-publishing', {
  redis: process.env.REDIS_URL || 'redis://localhost:6379',
  defaultJobOptions: {
    attempts: 3,
    backoff: { type: 'exponential', delay: 5000 },
    removeOnComplete: 100,
    removeOnFail: 50
  }
});

module.exports = { postQueue };
