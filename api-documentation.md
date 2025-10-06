# Physiotherapy Management System - API Documentation

## Base URL
- **Development**: `http://localhost:3000/api`
- **Production**: `https://api.physiomanagement.com/api`

## Authentication
All authenticated endpoints require a Bearer token in the Authorization header:
```
Authorization: Bearer <jwt_token>
```

## Response Format
All API responses follow this standard format:
```json
{
  "success": true,
  "data": {},
  "message": "Success message",
  "pagination": {
    "page": 1,
    "limit": 10,
    "total": 100,
    "totalPages": 10
  }
}
```

Error responses:
```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Error description",
    "details": {}
  }
}
```

## Authentication Endpoints

### POST /auth/register
Register a new user account.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "securePassword123",
  "firstName": "John",
  "lastName": "Doe",
  "phone": "+1234567890",
  "role": "patient",
  "dateOfBirth": "1990-01-01"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "firstName": "John",
      "lastName": "Doe",
      "role": "patient"
    },
    "token": "jwt_token",
    "refreshToken": "refresh_token"
  }
}
```

### POST /auth/login
Authenticate user and receive access token.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "securePassword123"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "firstName": "John",
      "lastName": "Doe",
      "role": "patient"
    },
    "token": "jwt_token",
    "refreshToken": "refresh_token"
  }
}
```

### POST /auth/refresh
Refresh access token using refresh token.

**Request Body:**
```json
{
  "refreshToken": "refresh_token"
}
```

### POST /auth/logout
Logout user and invalidate tokens.

**Headers:** `Authorization: Bearer <token>`

### POST /auth/forgot-password
Request password reset email.

**Request Body:**
```json
{
  "email": "user@example.com"
}
```

### POST /auth/reset-password
Reset password using reset token.

**Request Body:**
```json
{
  "token": "reset_token",
  "newPassword": "newSecurePassword123"
}
```

## User Management Endpoints

### GET /users/profile
Get current user's profile information.

**Headers:** `Authorization: Bearer <token>`

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "email": "user@example.com",
    "firstName": "John",
    "lastName": "Doe",
    "phone": "+1234567890",
    "role": "patient",
    "profilePictureUrl": "https://...",
    "createdAt": "2023-01-01T00:00:00Z"
  }
}
```

### PUT /users/profile
Update current user's profile.

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "firstName": "John",
  "lastName": "Doe",
  "phone": "+1234567890",
  "dateOfBirth": "1990-01-01"
}
```

### POST /users/upload-avatar
Upload profile picture.

**Headers:** `Authorization: Bearer <token>`
**Content-Type:** `multipart/form-data`

**Form Data:**
- `avatar`: Image file (JPG, PNG, max 5MB)

## Patient Management Endpoints

### GET /patients
Get list of patients (therapist/admin only).

**Headers:** `Authorization: Bearer <token>`
**Query Parameters:**
- `page`: Page number (default: 1)
- `limit`: Items per page (default: 10)
- `search`: Search by name or email
- `therapistId`: Filter by assigned therapist

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "firstName": "Jane",
      "lastName": "Doe",
      "email": "jane@example.com",
      "phone": "+1234567890",
      "insuranceProvider": "Blue Cross",
      "totalSessions": 5,
      "lastSessionDate": "2023-12-01T10:00:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 10,
    "total": 50,
    "totalPages": 5
  }
}
```

### GET /patients/:id
Get patient details.

**Headers:** `Authorization: Bearer <token>`

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "firstName": "Jane",
    "lastName": "Doe",
    "email": "jane@example.com",
    "phone": "+1234567890",
    "dateOfBirth": "1990-01-01",
    "medicalHistory": "Previous knee surgery...",
    "currentMedications": "Ibuprofen 400mg",
    "allergies": "None known",
    "emergencyContact": {
      "name": "John Doe",
      "phone": "+1234567891",
      "relationship": "Spouse"
    },
    "insurance": {
      "provider": "Blue Cross",
      "policyNumber": "BC123456"
    },
    "address": {
      "street": "123 Main St",
      "city": "Anytown",
      "state": "NY",
      "zipCode": "12345"
    }
  }
}
```

### PUT /patients/:id
Update patient information.

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "medicalHistory": "Updated medical history...",
  "currentMedications": "Updated medications",
  "allergies": "Penicillin",
  "emergencyContactName": "John Doe",
  "emergencyContactPhone": "+1234567891",
  "insuranceProvider": "Blue Cross",
  "insurancePolicyNumber": "BC123456"
}
```

### GET /patients/:id/sessions
Get patient's session history.

**Headers:** `Authorization: Bearer <token>`
**Query Parameters:**
- `page`: Page number
- `limit`: Items per page
- `startDate`: Filter sessions from date
- `endDate`: Filter sessions to date

## Physiotherapist Management Endpoints

### GET /physiotherapists
Get list of physiotherapists.

**Query Parameters:**
- `page`: Page number
- `limit`: Items per page
- `specialization`: Filter by specialization
- `availableDate`: Check availability for specific date

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "firstName": "Dr. John",
      "lastName": "Smith",
      "email": "dr.smith@example.com",
      "specializations": ["Orthopedic", "Sports Medicine"],
      "bio": "Experienced physiotherapist...",
      "hourlyRate": 120.00,
      "rating": 4.8,
      "totalReviews": 25,
      "isAcceptingPatients": true
    }
  ]
}
```

### GET /physiotherapists/:id
Get physiotherapist details.

### GET /physiotherapists/:id/availability
Get physiotherapist availability.

**Query Parameters:**
- `date`: Specific date (YYYY-MM-DD)
- `week`: Week starting date

**Response:**
```json
{
  "success": true,
  "data": {
    "date": "2023-12-01",
    "availableSlots": [
      {
        "startTime": "09:00",
        "endTime": "10:00",
        "available": true
      },
      {
        "startTime": "10:00",
        "endTime": "11:00",
        "available": false
      }
    ]
  }
}
```

## Appointment Management Endpoints

### GET /appointments
Get appointments list.

**Headers:** `Authorization: Bearer <token>`
**Query Parameters:**
- `page`: Page number
- `limit`: Items per page
- `status`: Filter by status
- `date`: Filter by date
- `patientId`: Filter by patient (therapist/admin only)
- `therapistId`: Filter by therapist

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "patientName": "Jane Doe",
      "therapistName": "Dr. John Smith",
      "appointmentDate": "2023-12-01T10:00:00Z",
      "duration": 60,
      "status": "scheduled",
      "appointmentType": "Follow-up",
      "notes": "Follow-up for knee rehabilitation"
    }
  ]
}
```

### POST /appointments
Create new appointment.

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "therapistId": "uuid",
  "appointmentDate": "2023-12-01T10:00:00Z",
  "duration": 60,
  "appointmentType": "Initial Assessment",
  "chiefComplaint": "Lower back pain",
  "notes": "Patient reports pain for 2 weeks"
}
```

### GET /appointments/:id
Get appointment details.

### PUT /appointments/:id
Update appointment.

**Request Body:**
```json
{
  "appointmentDate": "2023-12-01T11:00:00Z",
  "duration": 90,
  "notes": "Updated notes"
}
```

### DELETE /appointments/:id
Cancel appointment.

**Request Body:**
```json
{
  "cancellationReason": "Patient requested reschedule"
}
```

### POST /appointments/:id/confirm
Confirm appointment (therapist only).

### POST /appointments/:id/complete
Mark appointment as completed and create session record.

**Request Body:**
```json
{
  "sessionNotes": {
    "subjectiveNotes": "Patient reports decreased pain",
    "objectiveFindings": "Improved range of motion",
    "assessment": "Good progress",
    "plan": "Continue current exercises",
    "treatmentProvided": "Manual therapy and exercises",
    "painLevelBefore": 7,
    "painLevelAfter": 4
  }
}
```

## Session Management Endpoints

### GET /sessions
Get sessions list.

**Headers:** `Authorization: Bearer <token>`
**Query Parameters:**
- `page`: Page number
- `limit`: Items per page
- `patientId`: Filter by patient
- `therapistId`: Filter by therapist
- `startDate`: Filter from date
- `endDate`: Filter to date

### POST /sessions
Create session record.

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "appointmentId": "uuid",
  "patientId": "uuid",
  "sessionDate": "2023-12-01T10:00:00Z",
  "duration": 60,
  "subjectiveNotes": "Patient reports improvement",
  "objectiveFindings": "Increased ROM",
  "assessment": "Good progress",
  "plan": "Continue treatment",
  "treatmentProvided": "Manual therapy",
  "exercisesPrescribed": "Knee strengthening exercises",
  "painLevelBefore": 6,
  "painLevelAfter": 3
}
```

### GET /sessions/:id
Get session details.

### PUT /sessions/:id
Update session notes.

### GET /sessions/stats
Get session statistics.

**Headers:** `Authorization: Bearer <token>`
**Query Parameters:**
- `period`: 'week', 'month', 'year'
- `therapistId`: Filter by therapist (admin only)

**Response:**
```json
{
  "success": true,
  "data": {
    "totalSessions": 150,
    "completedSessions": 140,
    "cancelledSessions": 10,
    "averagePainReduction": 3.2,
    "patientSatisfaction": 4.7,
    "revenueGenerated": 18000.00
  }
}
```

## Billing & Payment Endpoints

### GET /invoices
Get invoices list.

**Headers:** `Authorization: Bearer <token>`
**Query Parameters:**
- `page`: Page number
- `limit`: Items per page
- `status`: Filter by status
- `patientId`: Filter by patient
- `dueDate`: Filter by due date

### POST /invoices
Create invoice.

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "patientId": "uuid",
  "sessionId": "uuid",
  "amount": 120.00,
  "taxRate": 0.0875,
  "description": "Physical therapy session",
  "dueDate": "2023-12-31"
}
```

### GET /invoices/:id
Get invoice details.

### PUT /invoices/:id
Update invoice.

### POST /invoices/:id/send
Send invoice to patient via email.

### POST /payments/create-intent
Create payment intent for Stripe.

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "invoiceId": "uuid",
  "paymentMethodId": "pm_stripe_id"
}
```

### POST /payments/confirm
Confirm payment.

**Request Body:**
```json
{
  "paymentIntentId": "pi_stripe_id",
  "invoiceId": "uuid"
}
```

### GET /payments/:id
Get payment details.

## Video Management Endpoints

### GET /videos
Get videos list.

**Headers:** `Authorization: Bearer <token>`
**Query Parameters:**
- `page`: Page number
- `limit`: Items per page
- `type`: Filter by video type
- `patientId`: Filter by patient
- `isPublic`: Filter public videos

### POST /videos/upload
Upload video file.

**Headers:** `Authorization: Bearer <token>`
**Content-Type:** `multipart/form-data`

**Form Data:**
- `video`: Video file (MP4, MOV, AVI, max 500MB)
- `title`: Video title
- `description`: Video description
- `type`: Video type ('initial_assessment', 'treatment', 'exercise', 'progress')
- `patientId`: Associated patient ID (optional)
- `tags`: Comma-separated tags

### GET /videos/:id
Get video details.

### PUT /videos/:id
Update video metadata.

**Request Body:**
```json
{
  "title": "Updated title",
  "description": "Updated description",
  "tags": ["exercise", "knee", "rehabilitation"],
  "isPublic": false
}
```

### DELETE /videos/:id
Delete video.

### GET /videos/:id/stream
Stream video content.

**Query Parameters:**
- `quality`: Video quality ('720p', '480p', '360p')

## Exercise Library Endpoints

### GET /exercises
Get exercises library.

**Query Parameters:**
- `page`: Page number
- `limit`: Items per page
- `category`: Filter by category
- `bodyPart`: Filter by body part
- `difficulty`: Filter by difficulty level

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "name": "Knee Extension",
      "description": "Strengthen quadriceps muscles",
      "category": "Strength",
      "bodyPart": "Knee",
      "difficulty": 2,
      "duration": 15,
      "repetitions": 10,
      "sets": 3,
      "equipmentNeeded": ["Resistance band"],
      "videoUrl": "https://...",
      "imageUrl": "https://..."
    }
  ]
}
```

### POST /exercises
Create new exercise (therapist only).

### GET /exercises/:id
Get exercise details.

### PUT /exercises/:id
Update exercise.

### DELETE /exercises/:id
Delete exercise.

### POST /exercises/:id/assign
Assign exercise to patient.

**Request Body:**
```json
{
  "patientId": "uuid",
  "targetRepetitions": 10,
  "targetSets": 3,
  "targetFrequency": "Daily",
  "specialInstructions": "Start with low resistance"
}
```

### GET /patients/:patientId/exercises
Get patient's assigned exercises.

### POST /exercises/completion
Record exercise completion.

**Request Body:**
```json
{
  "patientExerciseId": "uuid",
  "repetitionsCompleted": 10,
  "setsCompleted": 3,
  "duration": 15,
  "painLevelBefore": 5,
  "painLevelAfter": 3,
  "difficultyRating": 3,
  "notes": "Felt good today"
}
```

## Notification Endpoints

### GET /notifications
Get user notifications.

**Headers:** `Authorization: Bearer <token>`
**Query Parameters:**
- `page`: Page number
- `limit`: Items per page
- `isRead`: Filter by read status

### PUT /notifications/:id/read
Mark notification as read.

### POST /notifications/preferences
Update notification preferences.

**Request Body:**
```json
{
  "emailNotifications": true,
  "pushNotifications": true,
  "smsNotifications": false,
  "appointmentReminders": true,
  "paymentReminders": true
}
```

## Communication Endpoints

### GET /messages
Get messages.

**Headers:** `Authorization: Bearer <token>`
**Query Parameters:**
- `page`: Page number
- `limit`: Items per page
- `conversationWith`: Filter by conversation partner

### POST /messages
Send message.

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "recipientId": "uuid",
  "subject": "Question about exercises",
  "messageText": "I have a question about the knee exercises...",
  "parentMessageId": "uuid"
}
```

### GET /messages/:id
Get message details.

### PUT /messages/:id/read
Mark message as read.

## Review & Rating Endpoints

### GET /reviews
Get reviews.

**Query Parameters:**
- `therapistId`: Filter by therapist
- `page`: Page number
- `limit`: Items per page

### POST /reviews
Create review.

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "therapistId": "uuid",
  "sessionId": "uuid",
  "rating": 5,
  "reviewText": "Excellent service and care",
  "isAnonymous": false
}
```

## Analytics & Reporting Endpoints

### GET /analytics/dashboard
Get dashboard analytics.

**Headers:** `Authorization: Bearer <token>`
**Query Parameters:**
- `period`: 'week', 'month', 'quarter', 'year'

**Response:**
```json
{
  "success": true,
  "data": {
    "totalPatients": 150,
    "totalSessions": 1200,
    "totalRevenue": 144000.00,
    "averageRating": 4.8,
    "sessionCompletionRate": 0.95,
    "patientRetentionRate": 0.85,
    "monthlyGrowth": 0.12
  }
}
```

### GET /analytics/revenue
Get revenue analytics.

### GET /analytics/patients
Get patient analytics.

### GET /analytics/sessions
Get session analytics.

## System Settings Endpoints

### GET /settings
Get system settings (admin only).

### PUT /settings
Update system settings (admin only).

**Request Body:**
```json
{
  "appointmentDurationDefault": 60,
  "businessHoursStart": "08:00",
  "businessHoursEnd": "18:00",
  "taxRate": 0.0875
}
```

## Error Codes

| Code | Description |
|------|-------------|
| `VALIDATION_ERROR` | Request validation failed |
| `AUTHENTICATION_REQUIRED` | Authentication token required |
| `INVALID_CREDENTIALS` | Invalid email or password |
| `INSUFFICIENT_PERMISSIONS` | User lacks required permissions |
| `RESOURCE_NOT_FOUND` | Requested resource not found |
| `RESOURCE_CONFLICT` | Resource conflict (e.g., duplicate email) |
| `RATE_LIMIT_EXCEEDED` | Too many requests |
| `FILE_TOO_LARGE` | Uploaded file exceeds size limit |
| `INVALID_FILE_TYPE` | Unsupported file type |
| `PAYMENT_FAILED` | Payment processing failed |
| `APPOINTMENT_CONFLICT` | Appointment time conflict |
| `INTERNAL_SERVER_ERROR` | Server error |

## Rate Limiting

API endpoints are rate limited to prevent abuse:
- **Authentication endpoints**: 5 requests per minute
- **File upload endpoints**: 10 requests per hour
- **General endpoints**: 100 requests per minute
- **Public endpoints**: 1000 requests per hour

Rate limit headers are included in responses:
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1640995200
```

## Webhooks

The system supports webhooks for real-time notifications:

### Payment Events
- `payment.succeeded`
- `payment.failed`
- `invoice.payment_succeeded`

### Appointment Events
- `appointment.created`
- `appointment.updated`
- `appointment.cancelled`
- `appointment.completed`

### Webhook Payload Example
```json
{
  "id": "evt_uuid",
  "type": "appointment.created",
  "created": 1640995200,
  "data": {
    "object": {
      "id": "uuid",
      "patientId": "uuid",
      "therapistId": "uuid",
      "appointmentDate": "2023-12-01T10:00:00Z",
      "status": "scheduled"
    }
  }
}
```

## SDK Examples

### JavaScript/TypeScript
```javascript
import { PhysioAPI } from '@physio/api-client';

const api = new PhysioAPI({
  baseURL: 'https://api.physiomanagement.com/api',
  apiKey: 'your-api-key'
});

// Get appointments
const appointments = await api.appointments.list({
  page: 1,
  limit: 10,
  status: 'scheduled'
});

// Create appointment
const newAppointment = await api.appointments.create({
  therapistId: 'uuid',
  appointmentDate: '2023-12-01T10:00:00Z',
  duration: 60,
  appointmentType: 'Initial Assessment'
});
```

### Python
```python
from physio_api import PhysioClient

client = PhysioClient(
    base_url='https://api.physiomanagement.com/api',
    api_key='your-api-key'
)

# Get appointments
appointments = client.appointments.list(
    page=1,
    limit=10,
    status='scheduled'
)

# Create appointment
new_appointment = client.appointments.create({
    'therapist_id': 'uuid',
    'appointment_date': '2023-12-01T10:00:00Z',
    'duration': 60,
    'appointment_type': 'Initial Assessment'
})
```

This API documentation provides comprehensive coverage of all endpoints needed for the physiotherapy management system, including authentication, patient management, appointments, billing, video handling, and more.