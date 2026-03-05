import { createConsumer } from "@rails/actioncable"

// Shared ActionCable consumer — reused across all controllers to avoid
// creating a new WebSocket connection on each Stimulus controller connect.
export default createConsumer()
