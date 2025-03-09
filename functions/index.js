/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

const { onCall } = require("firebase-functions/v2/https");
const nodemailer = require("nodemailer");

const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: "your-email@gmail.com",
    pass: "your-app-password", // Use an App Password, not your real password
  },
});

exports.sendEmergencyEmail = onCall(async (data) => {
  const { userEmail, contacts, location, userName, alertMessage, reason } = data;

  if (!contacts || !contacts.length) {
    throw new Error("Emergency contacts are required");
  }

  // Default message if alertMessage is not provided
  const message = alertMessage || `${userName} has triggered an emergency alert`;
  
  // Email subject based on reason
  let subject = "EMERGENCY ALERT!";
  if (reason === 'device_stolen') {
    subject = "URGENT: Device Stolen Alert!";
  }

  try {
    const emailPromises = contacts.map(contact => {
      if (!contact.email) return Promise.resolve(); // Skip if no email

      const mailOptions = {
        from: "your-email@gmail.com",
        to: contact.email,
        subject: subject,
        text: `${message} at ${location}. This is an automated emergency alert.`,
        html: `
          <h1 style="color: red;">${subject}</h1>
          <p><strong>${message}</strong> at:</p>
          <p>${location.replace('\n', '<br>')}</p>
          <p>This is an automated emergency alert sent from their device.</p>
        `
      };

      return transporter.sendMail(mailOptions);
    });

    await Promise.all(emailPromises);
    return { success: true };
  } catch (error) {
    console.error("Error sending emails:", error);
    return { success: false, error: error.message };
  }
});