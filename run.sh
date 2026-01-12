#!/bin/sh
echo "Starting camera proxy..."
echo " URL: $APP_CAM_URL"
echo " OUT: $APP_RTSP_URL"

publish_stream () {
    curl "$APP_CAM_URL" -k --ignore-content-length \
        --output - | \
    ffmpeg -y -i - \
        -c:v copy -c:a copy \
        -f rtsp -rtsp_transport tcp "$APP_RTSP_URL"
}

# Retry function with 30-second reset logic
publish_stream_with_retry() {
    local max_retries=10
    local retry_delay=5
    local attempt=1
    
    while true; do
        echo "Attempt $attempt/$max_retries to publish stream..."
        
        # Start timing for this attempt
        local start_time=$(date +%s)
        
        if publish_stream; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            
            echo "Stream published successfully in $duration seconds!"
            
            # Reset retry counter on any successful publish
            echo "Success detected. Resetting retry counter to 1."
            attempt=1
            retry_delay=5
            
            # Wait before next attempt
            echo "Waiting before next attempt..."
            sleep 10
            continue
        else
            local exit_code=$?
            echo "Stream publish failed (exit code: $exit_code)"
            
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            
            # Only increment retry counter if failure happens within 30 seconds
            if [ $duration -le 30 ]; then
                # Failure within 30 seconds - increment retry counter
                attempt=$((attempt + 1))
                if [ $attempt -gt $max_retries ]; then
                    echo "Max retries reached. Exiting."
                    return 1
                fi
                echo "Failure within 30s, incrementing retry counter to $attempt"
            else
                # Failure after 30 seconds - reset retry counter and don't increment
                echo "Failure occurred after 30 seconds, resetting retry counter to 1."
                attempt=1
                retry_delay=5
            fi
            
            echo "Retrying in $retry_delay seconds..."
            sleep $retry_delay
            retry_delay=$((retry_delay * 2))  # Exponential backoff
        fi
    done
}

# Main execution
publish_stream_with_retry
