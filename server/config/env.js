const path = require('path');
const envFileName = process.env.DOTENV_CONFIG_PATH || (process.env.NODE_ENV === 'staging' ? '.env.staging' : '.env');
require('dotenv').config({ path: path.join(__dirname, '../../', envFileName) });

/**
 * Single source of the JWT signing secret for every module.
 * Why: several files used different hardcoded fallbacks, so tokens signed in one
 * place failed verification in another, and a known default made tokens forgeable.
 * Fails closed: only an explicit NODE_ENV=development|test may fall back to a
 * clearly fake dev secret; anything else (production, staging, unset) must set a
 * real one. The .env.example placeholder is treated as unset.
 * @returns {string}
 */
function resolveJwtSecret() {
  const secret = process.env.JWT_SECRET;
  if (secret && secret !== 'your_jwt_secret_here') return secret;
  if (!['development', 'test'].includes(process.env.NODE_ENV)) {
    throw new Error('JWT_SECRET must be set (only NODE_ENV=development|test may run without it).');
  }
  console.warn('[env] JWT_SECRET is not set; using an insecure development-only secret.');
  return 'dev-only-insecure-jwt-secret';
}

module.exports = {
  PORT: process.env.PORT || 3000,
  MONGO_URI: process.env.MONGODB_URI || process.env.MONGO_URI || 'mongodb://localhost:27017/lms-platform',
  JWT_SECRET: resolveJwtSecret(),
  // 30 days, matching the OTP logins. Was 1d, which signed every password
  // login out daily. Active clients extend it through POST /auth/refresh.
  JWT_EXPIRES_IN: process.env.JWT_EXPIRES_IN || '30d',
  NODE_ENV: process.env.NODE_ENV || 'development'
};
