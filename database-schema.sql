-- Physiotherapy Management System Database Schema
-- PostgreSQL 15+ compatible

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create custom types
CREATE TYPE user_role AS ENUM ('patient', 'physiotherapist', 'admin');
CREATE TYPE appointment_status AS ENUM ('scheduled', 'confirmed', 'completed', 'cancelled', 'no_show');
CREATE TYPE invoice_status AS ENUM ('pending', 'paid', 'overdue', 'cancelled');
CREATE TYPE video_type AS ENUM ('initial_assessment', 'treatment', 'exercise', 'progress');
CREATE TYPE notification_type AS ENUM ('appointment_reminder', 'payment_due', 'session_completed', 'video_uploaded', 'system');

-- Users table (base table for all system users)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role user_role NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    date_of_birth DATE,
    profile_picture_url VARCHAR(500),
    is_active BOOLEAN DEFAULT TRUE,
    email_verified BOOLEAN DEFAULT FALSE,
    last_login TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Patients table (extends users for patient-specific data)
CREATE TABLE patients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    medical_history TEXT,
    current_medications TEXT,
    allergies TEXT,
    emergency_contact_name VARCHAR(100),
    emergency_contact_phone VARCHAR(20),
    emergency_contact_relationship VARCHAR(50),
    insurance_provider VARCHAR(100),
    insurance_policy_number VARCHAR(50),
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(50),
    zip_code VARCHAR(20),
    country VARCHAR(50) DEFAULT 'USA',
    preferred_language VARCHAR(20) DEFAULT 'English',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Physiotherapists table (extends users for therapist-specific data)
CREATE TABLE physiotherapists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    license_number VARCHAR(50) UNIQUE NOT NULL,
    license_expiry_date DATE,
    specializations TEXT[],
    bio TEXT,
    education TEXT,
    certifications TEXT[],
    years_of_experience INTEGER,
    hourly_rate DECIMAL(10,2),
    availability_schedule JSONB, -- Store weekly schedule as JSON
    is_accepting_patients BOOLEAN DEFAULT TRUE,
    rating DECIMAL(3,2) DEFAULT 0.00,
    total_reviews INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Appointments table
CREATE TABLE appointments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    physiotherapist_id UUID NOT NULL REFERENCES physiotherapists(id) ON DELETE CASCADE,
    appointment_date TIMESTAMP NOT NULL,
    duration_minutes INTEGER DEFAULT 60,
    status appointment_status DEFAULT 'scheduled',
    appointment_type VARCHAR(100), -- e.g., 'Initial Assessment', 'Follow-up', 'Maintenance'
    chief_complaint TEXT,
    notes TEXT,
    cancellation_reason TEXT,
    cancelled_by UUID REFERENCES users(id),
    cancelled_at TIMESTAMP,
    confirmed_at TIMESTAMP,
    reminder_sent BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Sessions table (records of completed appointments)
CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    appointment_id UUID UNIQUE REFERENCES appointments(id) ON DELETE CASCADE,
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    physiotherapist_id UUID NOT NULL REFERENCES physiotherapists(id) ON DELETE CASCADE,
    session_date TIMESTAMP NOT NULL,
    duration_minutes INTEGER NOT NULL,
    session_number INTEGER, -- Track session count for the patient
    subjective_notes TEXT, -- Patient's reported symptoms/progress
    objective_findings TEXT, -- Therapist's observations and measurements
    assessment TEXT, -- Clinical assessment and diagnosis
    plan TEXT, -- Treatment plan and next steps
    treatment_provided TEXT,
    exercises_prescribed TEXT,
    home_program TEXT,
    progress_notes TEXT,
    pain_level_before INTEGER CHECK (pain_level_before >= 0 AND pain_level_before <= 10),
    pain_level_after INTEGER CHECK (pain_level_after >= 0 AND pain_level_after <= 10),
    functional_improvement TEXT,
    next_session_recommendations TEXT,
    goals_achieved TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Invoices table
CREATE TABLE invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_number VARCHAR(50) UNIQUE NOT NULL,
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    session_id UUID REFERENCES sessions(id) ON DELETE SET NULL,
    physiotherapist_id UUID NOT NULL REFERENCES physiotherapists(id) ON DELETE CASCADE,
    amount DECIMAL(10,2) NOT NULL,
    tax_rate DECIMAL(5,4) DEFAULT 0.0000,
    tax_amount DECIMAL(10,2) DEFAULT 0,
    discount_amount DECIMAL(10,2) DEFAULT 0,
    total_amount DECIMAL(10,2) NOT NULL,
    status invoice_status DEFAULT 'pending',
    description TEXT,
    due_date DATE NOT NULL,
    issued_date DATE DEFAULT CURRENT_DATE,
    paid_at TIMESTAMP,
    payment_method VARCHAR(50),
    transaction_id VARCHAR(100),
    stripe_payment_intent_id VARCHAR(100),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Videos table
CREATE TABLE videos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    uploader_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    patient_id UUID REFERENCES patients(id) ON DELETE CASCADE,
    session_id UUID REFERENCES sessions(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    file_url VARCHAR(500) NOT NULL,
    thumbnail_url VARCHAR(500),
    file_name VARCHAR(255),
    file_size BIGINT,
    duration_seconds INTEGER,
    video_type video_type NOT NULL,
    tags TEXT[],
    is_public BOOLEAN DEFAULT FALSE,
    is_processed BOOLEAN DEFAULT FALSE,
    processing_status VARCHAR(50) DEFAULT 'pending', -- pending, processing, completed, failed
    view_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Exercise library table
CREATE TABLE exercises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    instructions TEXT,
    category VARCHAR(100), -- e.g., 'Strength', 'Flexibility', 'Balance'
    body_part VARCHAR(100), -- e.g., 'Lower Back', 'Shoulder', 'Knee'
    difficulty_level INTEGER CHECK (difficulty_level >= 1 AND difficulty_level <= 5),
    duration_minutes INTEGER,
    repetitions INTEGER,
    sets INTEGER,
    equipment_needed TEXT[],
    contraindications TEXT,
    video_url VARCHAR(500),
    image_url VARCHAR(500),
    created_by UUID REFERENCES physiotherapists(id),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Patient exercise assignments
CREATE TABLE patient_exercises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    exercise_id UUID NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
    session_id UUID REFERENCES sessions(id) ON DELETE SET NULL,
    assigned_by UUID NOT NULL REFERENCES physiotherapists(id) ON DELETE CASCADE,
    assigned_date DATE DEFAULT CURRENT_DATE,
    target_repetitions INTEGER,
    target_sets INTEGER,
    target_frequency VARCHAR(50), -- e.g., 'Daily', '3x per week'
    special_instructions TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    completed_sessions INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Exercise completion tracking
CREATE TABLE exercise_completions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_exercise_id UUID NOT NULL REFERENCES patient_exercises(id) ON DELETE CASCADE,
    completion_date DATE DEFAULT CURRENT_DATE,
    repetitions_completed INTEGER,
    sets_completed INTEGER,
    duration_minutes INTEGER,
    pain_level_before INTEGER CHECK (pain_level_before >= 0 AND pain_level_before <= 10),
    pain_level_after INTEGER CHECK (pain_level_after >= 0 AND pain_level_after <= 10),
    difficulty_rating INTEGER CHECK (difficulty_rating >= 1 AND difficulty_rating <= 5),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Notifications table
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type notification_type NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    related_id UUID, -- Can reference appointment, session, invoice, etc.
    is_read BOOLEAN DEFAULT FALSE,
    is_sent BOOLEAN DEFAULT FALSE,
    send_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    read_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Reviews and ratings table
CREATE TABLE reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    physiotherapist_id UUID NOT NULL REFERENCES physiotherapists(id) ON DELETE CASCADE,
    session_id UUID REFERENCES sessions(id) ON DELETE SET NULL,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    review_text TEXT,
    is_anonymous BOOLEAN DEFAULT FALSE,
    is_approved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(patient_id, session_id) -- One review per session
);

-- Messages table for in-app communication
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    recipient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    subject VARCHAR(255),
    message_text TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP,
    parent_message_id UUID REFERENCES messages(id) ON DELETE SET NULL,
    attachment_url VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- System settings table
CREATE TABLE system_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    setting_key VARCHAR(100) UNIQUE NOT NULL,
    setting_value TEXT,
    description TEXT,
    is_public BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Audit log table for tracking changes
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    table_name VARCHAR(100) NOT NULL,
    record_id UUID NOT NULL,
    action VARCHAR(20) NOT NULL, -- INSERT, UPDATE, DELETE
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_appointments_patient_id ON appointments(patient_id);
CREATE INDEX idx_appointments_physiotherapist_id ON appointments(physiotherapist_id);
CREATE INDEX idx_appointments_date ON appointments(appointment_date);
CREATE INDEX idx_appointments_status ON appointments(status);
CREATE INDEX idx_sessions_patient_id ON sessions(patient_id);
CREATE INDEX idx_sessions_physiotherapist_id ON sessions(physiotherapist_id);
CREATE INDEX idx_sessions_date ON sessions(session_date);
CREATE INDEX idx_invoices_patient_id ON invoices(patient_id);
CREATE INDEX idx_invoices_status ON invoices(status);
CREATE INDEX idx_invoices_due_date ON invoices(due_date);
CREATE INDEX idx_videos_patient_id ON videos(patient_id);
CREATE INDEX idx_videos_uploader_id ON videos(uploader_id);
CREATE INDEX idx_videos_type ON videos(video_type);
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_is_read ON notifications(is_read);
CREATE INDEX idx_messages_sender_id ON messages(sender_id);
CREATE INDEX idx_messages_recipient_id ON messages(recipient_id);
CREATE INDEX idx_audit_logs_table_record ON audit_logs(table_name, record_id);

-- Create triggers for updated_at timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_patients_updated_at BEFORE UPDATE ON patients FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_physiotherapists_updated_at BEFORE UPDATE ON physiotherapists FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_appointments_updated_at BEFORE UPDATE ON appointments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_sessions_updated_at BEFORE UPDATE ON sessions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_invoices_updated_at BEFORE UPDATE ON invoices FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_videos_updated_at BEFORE UPDATE ON videos FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_exercises_updated_at BEFORE UPDATE ON exercises FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_patient_exercises_updated_at BEFORE UPDATE ON patient_exercises FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_reviews_updated_at BEFORE UPDATE ON reviews FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_system_settings_updated_at BEFORE UPDATE ON system_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to automatically update physiotherapist ratings
CREATE OR REPLACE FUNCTION update_physiotherapist_rating()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE physiotherapists 
    SET 
        rating = (
            SELECT COALESCE(AVG(rating::DECIMAL), 0.00)
            FROM reviews 
            WHERE physiotherapist_id = NEW.physiotherapist_id 
            AND is_approved = TRUE
        ),
        total_reviews = (
            SELECT COUNT(*)
            FROM reviews 
            WHERE physiotherapist_id = NEW.physiotherapist_id 
            AND is_approved = TRUE
        )
    WHERE id = NEW.physiotherapist_id;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_physiotherapist_rating_trigger 
    AFTER INSERT OR UPDATE ON reviews 
    FOR EACH ROW 
    EXECUTE FUNCTION update_physiotherapist_rating();

-- Function to generate invoice numbers
CREATE OR REPLACE FUNCTION generate_invoice_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.invoice_number IS NULL THEN
        NEW.invoice_number := 'INV-' || TO_CHAR(CURRENT_DATE, 'YYYY') || '-' || 
                             LPAD(NEXTVAL('invoice_number_seq')::TEXT, 6, '0');
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create sequence for invoice numbers
CREATE SEQUENCE invoice_number_seq START 1;

CREATE TRIGGER generate_invoice_number_trigger 
    BEFORE INSERT ON invoices 
    FOR EACH ROW 
    EXECUTE FUNCTION generate_invoice_number();

-- Insert default system settings
INSERT INTO system_settings (setting_key, setting_value, description, is_public) VALUES
('appointment_duration_default', '60', 'Default appointment duration in minutes', TRUE),
('appointment_buffer_time', '15', 'Buffer time between appointments in minutes', TRUE),
('business_hours_start', '08:00', 'Business hours start time', TRUE),
('business_hours_end', '18:00', 'Business hours end time', TRUE),
('working_days', '["monday", "tuesday", "wednesday", "thursday", "friday"]', 'Working days of the week', TRUE),
('timezone', 'America/New_York', 'System timezone', TRUE),
('currency', 'USD', 'System currency', TRUE),
('tax_rate', '0.0875', 'Default tax rate (8.75%)', FALSE),
('late_fee_percentage', '0.05', 'Late fee percentage (5%)', FALSE),
('payment_terms_days', '30', 'Payment terms in days', TRUE),
('max_video_size_mb', '500', 'Maximum video file size in MB', TRUE),
('allowed_video_formats', '["mp4", "mov", "avi", "wmv"]', 'Allowed video file formats', TRUE),
('session_reminder_hours', '24', 'Hours before appointment to send reminder', TRUE),
('payment_reminder_days', '7', 'Days before due date to send payment reminder', TRUE);

-- Create views for common queries
CREATE VIEW patient_summary AS
SELECT 
    p.id,
    u.first_name,
    u.last_name,
    u.email,
    u.phone,
    p.insurance_provider,
    COUNT(DISTINCT s.id) as total_sessions,
    COUNT(DISTINCT a.id) as total_appointments,
    COALESCE(SUM(i.total_amount), 0) as total_billed,
    COALESCE(SUM(CASE WHEN i.status = 'paid' THEN i.total_amount ELSE 0 END), 0) as total_paid,
    MAX(s.session_date) as last_session_date
FROM patients p
JOIN users u ON p.user_id = u.id
LEFT JOIN sessions s ON p.id = s.patient_id
LEFT JOIN appointments a ON p.id = a.patient_id
LEFT JOIN invoices i ON p.id = i.patient_id
GROUP BY p.id, u.first_name, u.last_name, u.email, u.phone, p.insurance_provider;

CREATE VIEW therapist_summary AS
SELECT 
    pt.id,
    u.first_name,
    u.last_name,
    u.email,
    u.phone,
    pt.specializations,
    pt.hourly_rate,
    pt.rating,
    pt.total_reviews,
    COUNT(DISTINCT s.id) as total_sessions,
    COUNT(DISTINCT CASE WHEN a.appointment_date >= CURRENT_DATE THEN a.id END) as upcoming_appointments,
    COALESCE(SUM(i.total_amount), 0) as total_revenue
FROM physiotherapists pt
JOIN users u ON pt.user_id = u.id
LEFT JOIN sessions s ON pt.id = s.physiotherapist_id
LEFT JOIN appointments a ON pt.id = a.physiotherapist_id
LEFT JOIN invoices i ON pt.id = i.physiotherapist_id
GROUP BY pt.id, u.first_name, u.last_name, u.email, u.phone, pt.specializations, pt.hourly_rate, pt.rating, pt.total_reviews;

-- Create a view for appointment calendar
CREATE VIEW appointment_calendar AS
SELECT 
    a.id,
    a.appointment_date,
    a.duration_minutes,
    a.status,
    a.appointment_type,
    CONCAT(pu.first_name, ' ', pu.last_name) as patient_name,
    CONCAT(tu.first_name, ' ', tu.last_name) as therapist_name,
    pu.phone as patient_phone,
    tu.phone as therapist_phone,
    a.notes
FROM appointments a
JOIN patients p ON a.patient_id = p.id
JOIN users pu ON p.user_id = pu.id
JOIN physiotherapists pt ON a.physiotherapist_id = pt.id
JOIN users tu ON pt.user_id = tu.id
ORDER BY a.appointment_date;

-- Sample data (optional - for development/testing)
-- Uncomment the following lines to insert sample data

/*
-- Insert sample admin user
INSERT INTO users (email, password_hash, role, first_name, last_name, phone) VALUES
('admin@physio.com', '$2b$10$example_hash', 'admin', 'Admin', 'User', '+1234567890');

-- Insert sample physiotherapist
INSERT INTO users (email, password_hash, role, first_name, last_name, phone, date_of_birth) VALUES
('dr.smith@physio.com', '$2b$10$example_hash', 'physiotherapist', 'John', 'Smith', '+1234567891', '1980-05-15');

INSERT INTO physiotherapists (user_id, license_number, specializations, bio, hourly_rate) VALUES
((SELECT id FROM users WHERE email = 'dr.smith@physio.com'), 'PT12345', 
 ARRAY['Orthopedic', 'Sports Medicine'], 
 'Experienced physiotherapist specializing in sports injuries and orthopedic rehabilitation.',
 120.00);

-- Insert sample patient
INSERT INTO users (email, password_hash, role, first_name, last_name, phone, date_of_birth) VALUES
('patient@example.com', '$2b$10$example_hash', 'patient', 'Jane', 'Doe', '+1234567892', '1990-08-22');

INSERT INTO patients (user_id, medical_history, emergency_contact_name, emergency_contact_phone, address) VALUES
((SELECT id FROM users WHERE email = 'patient@example.com'), 
 'Previous knee surgery in 2020. No known allergies.',
 'John Doe', '+1234567893', '123 Main St, Anytown, NY 12345');
*/