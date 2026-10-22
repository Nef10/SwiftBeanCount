import Foundation

/// Verification document for the importer host's embedded browser. Rendering it contacts Google reCAPTCHA.
enum RitualVerificationPage {

    /// The origin registered for the mobile client's CAPTCHA
    static let baseURL = URL(string: "https://account.ritual.co/")!
    /// Public reCAPTCHA site key
    static let siteKey = "6Lerr_YhAAAAALEmlnXaaPX2DO2TbMq36qgw4c1r"
    /// Name of the WebKit script-message handler receiving verification results.
    static let messageHandler = "ritualVerification"

    /// Loads invisible verification, displaying an interactive challenge if Google requires one.
    /// The host must install the message handler and load this with baseURL; never evaluate captured challenge responses.
    static var html: String {
        """
        <!doctype html>
        <html lang="en">
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>Ritual sign-in</title>
            <style>body{font:17px system-ui;padding:24px}button{font:inherit;padding:8px 16px}</style>
        </head>
        <body>
            <h1>Ritual sign-in</h1><p>Complete verification to receive your sign-in code.</p>
            <div id="verification"></div>
            <button onclick="send({cancel:true})">Cancel</button>
            <script>
            function send(value) {
                window.webkit.messageHandlers.\(messageHandler).postMessage(value);
            }
            function verificationError() {
                send({error:true});
            }
            function ritualVerificationReady() {
                try {
                    var widget = grecaptcha.render('verification', {
                        sitekey: '\(siteKey)',
                        size: 'invisible',
                        callback: function(token) {
                            send({token:token});
                        },
                        'error-callback': verificationError,
                        'expired-callback': verificationError
                    });
                    grecaptcha.execute(widget);
                } catch (_) {
                    verificationError();
                }
            }
            </script>
            <script src="https://www.google.com/recaptcha/api.js?onload=ritualVerificationReady&amp;render=explicit" async defer onerror="verificationError()"></script>
            </body>
        </html>
        """
    }

}
