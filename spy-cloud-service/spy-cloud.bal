import ballerina/http;
import ballerina/log;

type User record {
    string userid;
    string email;
    string passwordHash;
};

// Define your users here
User[] users = [
    {userid: "", email: "", passwordHash: ""}
];
http:Client passwordHashApiClient = check new ("https://api.spycloud.io");
http:Client picScimApiClient = check new ("https://sandbox.play.picdemo.cloud");

int allowedReusedCount = 100;

function sendPasswordHashes(string hashValue) returns json|error? {

    string requestUrl = "/nist-password-v2/check/hashes/" + hashValue + "?type=sha256";

    // Set headers
    map<string> headers = {
        "Accept": "application/json",
        "x-api-key": "dY5M73VPgW1fz5gY5GiRP4s2roZEOz8G1Gx8WloH"
    };

    http:Response response = check passwordHashApiClient->get(requestUrl, headers);
    return response.getJsonPayload();
}

function sendForcedPasswordReset(string userId) returns http:Response|error {

    string requestUrl = "/t/carbon.super/scim2/Users/" + userId;

    // Set headers
    map<string> headers = {
        "Content-Type": "application/json",
        "Authorization": "Bearer e50aaef4-c7d0-3922-86ba-5793e080967d"
    };

    http:Response response = check picScimApiClient->patch(requestUrl,
    {
        "Operations":[
                {
                    "op":"add",
                    "value":{"urn:ietf:params:scim:schemas:extension:enterprise:2.0:User":{"forcePasswordReset":true}}
                }
            ],
        "schemas":[
            "urn:ietf:params:scim:api:messages:2.0:PatchOp"
            ]
    }, headers);
    return response;
}

public function main() returns error? {
    foreach var user in users {
        string firstFiveChars = user.passwordHash.substring(0, 5);
        json|error? sendPasswordHashesResult = sendPasswordHashes(firstFiveChars);
        if sendPasswordHashesResult is error {
            log:printError("Error in response", sendPasswordHashesResult);
        } else {
            json|error? errMessage = sendPasswordHashesResult.message;
            if sendPasswordHashesResult is json && errMessage is json {
                log:printError("Error in response: " + errMessage.toString());
            } else {
                map<json>|error? countsOfPasswords = check sendPasswordHashesResult.ensureType();
                if countsOfPasswords is map<json> {
                    json countJson = countsOfPasswords[user.passwordHash];
                    int reusedCount = check countJson.count;
                    if (reusedCount > allowedReusedCount) {
                        log:printInfo("*****Send forced password reset*****");
                        http:Response sendForcedPasswordResetResult = check sendForcedPasswordReset(user.userid);
                        if (sendForcedPasswordResetResult.statusCode == 200) {
                            log:printInfo("### Forced password reset sent successfully: " + user.email);
                        } else {
                            json responsePayload = check sendForcedPasswordResetResult.getJsonPayload();
                            log:printError("### Error while sending forced password reset: " + responsePayload.toString());
                        }
                    }
                } else {
                    log:printError("Error in response: ", countsOfPasswords);
                }
            }
        }
    }
}