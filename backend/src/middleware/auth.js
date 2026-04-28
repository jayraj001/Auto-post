const jwt = require('jsonwebtoken');
const { supabase } = require('../utils/supabase');

const authenticate = async (req, res, next) => {
  try {
    const header = req.headers.authorization;
    if (!header?.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'No token provided' });
    }
    const token = header.split(' ')[1];
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    const { data: user, error } = await supabase
      .from('users')
      .select('*')
      .eq('id', decoded.userId)
      .single();

    if (error || !user) return res.status(401).json({ error: 'Invalid token' });

    req.user = user;
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Token expired or invalid' });
  }
};

// Plan guard middleware factory
const requirePlan = (...plans) => (req, res, next) => {
  if (!plans.includes(req.user.plan)) {
    return res.status(403).json({
      error: 'Upgrade required',
      required_plans: plans,
      current_plan: req.user.plan
    });
  }
  next();
};

module.exports = { authenticate, requirePlan };
