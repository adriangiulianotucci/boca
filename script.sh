#!/bin/bash

# Alternative approach: Simulate the full queue flow
echo "Alternative approach: Simulating full queue flow..."

# Check if required environment variables are set
if [ -z "$BOCA_EMAIL" ] || [ -z "$BOCA_PASSWORD" ]; then
    echo "❌ Error: Required environment variables not set"
    echo "Please set BOCA_EMAIL and BOCA_PASSWORD environment variables"
    echo "Example:"
    echo "export BOCA_EMAIL='your-email@example.com'"
    echo "export BOCA_PASSWORD='your-base64-encoded-password'"
    exit 1
fi

echo "Using email: $BOCA_EMAIL"

# Step 1: Get the initial queue page
echo "Step 1: Getting initial queue page..."
INITIAL_RESPONSE=$(curl -s -c /tmp/cookies.txt 'https://bocasocios-gw.bocajuniors.com.ar/auth/login/baas' \
-X POST \
-H 'Host: bocasocios-gw.bocajuniors.com.ar' \
-H 'Accept: application/json, text/plain, */*' \
-H 'Connection: keep-alive' \
-H 'Accept-Language: es-419,es;q=0.9' \
-H 'User-Agent: BocaSocios/221 CFNetwork/3826.500.131 Darwin/24.5.0' \
-H 'Content-Type: application/json' \
--data-raw "{\"email\":\"$BOCA_EMAIL\",\"password\":\"$BOCA_PASSWORD\",\"expoDeviceId\":\"ExponentPushToken[A1arojFigfJ46b1Vnwrg2I]\",\"deviceOS\":\"IOS\"}")

echo "Initial response: $INITIAL_RESPONSE"

# Extract the new redirect URL
NEW_REDIRECT_URL=$(echo "$INITIAL_RESPONSE" | grep -o '"newRedirectUrl":"[^"]*"' | cut -d'"' -f4)

if [ -n "$NEW_REDIRECT_URL" ]; then
    echo "Step 2: Visiting new redirect URL: $NEW_REDIRECT_URL"
    
    # Step 2: Visit the new redirect URL and follow redirects
    QUEUE_PAGE=$(curl -s -b /tmp/cookies.txt -c /tmp/cookies.txt -L "$NEW_REDIRECT_URL")
    
    echo "Step 3: Waiting a moment to simulate queue processing..."
    sleep 2
    
    # Step 3: Try to access the queue status or complete the queue
    QUEUE_STATUS=$(curl -s -b /tmp/cookies.txt 'https://bocajuniors.queue-it.net/queue/status' \
    -H 'Referer: https://bocajuniors.queue-it.net/' \
    -H 'User-Agent: BocaSocios/221 CFNetwork/3826.500.131 Darwin/24.5.0')
    
    echo "Queue status: $QUEUE_STATUS"
    
    echo "Step 4: Making final authentication request..."
    
    # Step 4: Make the authentication request with updated cookies
    FINAL_RESPONSE=$(curl -s 'https://bocasocios-gw.bocajuniors.com.ar/auth/login/baas' \
    -X POST \
    -H 'Host: bocasocios-gw.bocajuniors.com.ar' \
    -H 'Accept: application/json, text/plain, */*' \
    -H 'Connection: keep-alive' \
    -H 'Accept-Language: es-419,es;q=0.9' \
    -H 'User-Agent: BocaSocios/221 CFNetwork/3826.500.131 Darwin/24.5.0' \
    -H 'Content-Type: application/json' \
    -b /tmp/cookies.txt \
    --data-raw "{\"email\":\"$BOCA_EMAIL\",\"password\":\"$BOCA_PASSWORD\",\"expoDeviceId\":\"ExponentPushToken[A1arojFigfJ46b1Vnwrg2I]\",\"deviceOS\":\"IOS\"}")
    
    echo "Final authentication response: $FINAL_RESPONSE"
    
    # Extract and display the token
    echo ""
    echo "🔑 EXTRACTED TOKEN:"
    TOKEN=$(echo "$FINAL_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    if [ -n "$TOKEN" ]; then
        echo "Access Token: $TOKEN"
        echo ""
        echo "📋 TOKEN DECODED (Payload):"
        # Extract the payload part of the JWT token (second part)
        PAYLOAD=$(echo "$TOKEN" | cut -d'.' -f2)
        if [ -n "$PAYLOAD" ]; then
            # Decode base64 and format JSON
            DECODED_PAYLOAD=$(echo "$PAYLOAD" | base64 -d 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "Could not decode token payload")
            echo "$DECODED_PAYLOAD"
        fi

        # Step 5: Make the matches request
        MATCHES_RESPONSE=$(curl -s 'https://bocasocios-gw.bocajuniors.com.ar/event/matches/plus' \
        -X POST \
        -H 'Host: bocasocios-gw.bocajuniors.com.ar' \
        -H 'Accept: application/json, text/plain, */*' \
        -H 'Connection: keep-alive' \
        -H 'Accept-Language: es-419,es;q=0.9' \
        -H "Authorization: Bearer $TOKEN" \
        -H 'User-Agent: BocaSocios/221 CFNetwork/3826.500.131 Darwin/24.5.0' \
        -H 'Content-Type: application/json' \
        -b /tmp/cookies.txt \
        --data-raw '{"abonado":false,"socioTipo":"adherente","familiarAbonado":false,"tieneAbonoDiscapacitado":false}')

        echo "Matches response: $MATCHES_RESPONSE"

        if [ -n "$MATCHES_RESPONSE" ]; then
            echo "Matches response: $MATCHES_RESPONSE"
            echo ""
            echo "📊 MATCHES RESPONSE ANALYSIS:"
            
            # Check if response contains actual data (not empty array)
            if echo "$MATCHES_RESPONSE" | grep -q '\[\]'; then
                echo "❌ Response contains empty array []"
            elif echo "$MATCHES_RESPONSE" | grep -q 'null'; then
                echo "❌ Response contains null"
            elif echo "$MATCHES_RESPONSE" | grep -q '""'; then
                echo "❌ Response contains empty string"
            else
                echo "✅ Response contains data"
                
                curl -s ntfy.sh/boca_socios_adrian -d "🎉 Boca Socios - Partido disponible" -X POST --data-raw "$MATCHES_RESPONSE"
            fi
        else
            echo "❌ No matches response found"
        fi
    else
        echo "❌ No token found in response"
    fi
else
    echo "No new redirect URL found"
fi

# Clean up
rm -f /tmp/cookies.txt 
