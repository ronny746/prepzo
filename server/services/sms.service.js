const axios = require('axios');
const crypto = require('crypto');

/**
 * Send OTP to Mobile Number
 * @param {string} phone - Target mobile number
 * @returns {object} - Status and generated OTP to save in DB
 */
const sendMobileOTP = async (phone) => {
    // 1. Phone number formatting (extra characters hatana aur 10 digits lena)
    const cleanPhone = String(phone).replace(/\D/g, '').slice(-10);
    
    if (cleanPhone.length !== 10) {
        return { success: false, message: "Invalid 10-digit mobile number" };
    }

    // Why: the provider key used to be hardcoded in this file (and so in git).
    const apiKey = process.env.SMS_API_KEY;
    if (!apiKey) {
        console.error('[SMS OTP ERROR]: SMS_API_KEY is not configured.');
        return { success: false, message: "SMS is not configured" };
    }

    // 2. 6-Digit cryptographically random OTP
    const generatedOtp = crypto.randomInt(100000, 1000000).toString();

    // 3. Exact approved message setup karna 
    const message = `Dear User Your OTP is ${generatedOtp} for mobile number verification. It is valid for 5 minutes. Please do not share with anyone - CSOCIT`;
    
    // URL me space/special characters handle karne ke liye encode karna
    const encodedMsg = encodeURIComponent(message);
    
    // 4. API URL banakar params bhejna
    const url = `https://login.bulksenders.in/app/smsapi/index.php?key=${encodeURIComponent(apiKey)}&campaign=12417&routeid=3&type=text&contacts=${cleanPhone}&senderid=CSOCIT&msg=${encodedMsg}&template_id=1707173399550602618&pe_id=1701171048184684059`;

    try {
        // 5. BulkSenders par HTTP request lagana
        const response = await axios.get(url);
        console.log(`[SMS OTP] Message successfully sent to ${cleanPhone}`);
        
        // Response me original OTP bhi bhejenge taaki DataBase (MongoDB vagera) me save kar sako
        return { 
            success: true, 
            message: "OTP sent successfully",
            otp: generatedOtp 
        };
    } catch (error) {
        console.error(`[SMS OTP ERROR]: API Failed for ${cleanPhone}`, error.message);
        return { 
            success: false, 
            message: "SMS API Failed",
            error: error.message 
        };
    }
};

module.exports = { sendMobileOTP };
