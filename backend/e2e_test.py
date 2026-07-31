import requests
import sys
from datetime import datetime, timezone

BASE_URL = "http://localhost:8000"
client = requests.Session()
admin_client = requests.Session()

def check(name, resp, expected_status=200):
    if resp.status_code != expected_status:
        print(f"FAIL: {name} (Expected {expected_status}, got {resp.status_code})")
        print(resp.text)
        sys.exit(1)
    print(f"PASS: {name}")
    return resp.json()

print("--- E2E Tests ---")

# 1. Student Flow
print("\n--- Student ---")
# Register
payload = {
    "name": "E2E Student",
    "email": "e2e@studybook.com",
    "phone": "1234567890",
    "password": "password123",
    "class_level": "10"
}
resp = client.post(f"{BASE_URL}/api/auth/register", json=payload)
if resp.status_code == 400 and "already registered" in resp.text:
    print("User already registered, logging in instead.")
    resp = client.post(f"{BASE_URL}/api/auth/login", json={"email": "e2e@studybook.com", "password": "password123"})
check("Student Login/Register", resp)

# Profile Update
resp = client.post(f"{BASE_URL}/api/auth/profile", json={"name": "E2E Student Updated", "phone": "0987654321"})
check("Student Profile Update", resp)

# Profile Request Class Change
resp = client.post(f"{BASE_URL}/api/auth/profile/request-class-change", json={"requested_class": "9"})
check("Student Request Class Change", resp)

# Question Bank Search
resp = client.get(f"{BASE_URL}/api/questions?class_level=10&subject=maths&search=algebra")
check("Question Bank Search", resp)

# View Analytics (Subscription Status is part of GET /api/auth/me)
resp = client.get(f"{BASE_URL}/api/auth/me")
student_data = check("Student Get Me (Subscription Status)", resp)

# 2. Admin Flow
print("\n--- Admin ---")
resp = admin_client.post(f"{BASE_URL}/api/auth/login", json={"email": "admin@studybook.com", "password": "adminpassword123"})
admin_data = check("Admin Login", resp)

# Manage Users (List, Edit, Toggle Subscription)
resp = admin_client.get(f"{BASE_URL}/api/admin/users?limit=10")
users_data = check("Admin List Users", resp)
student_id = student_data["_id"]

resp = admin_client.put(f"{BASE_URL}/api/admin/users/{student_id}", json={"name": "E2E Student Mod"})
check("Admin Edit User", resp)

resp = admin_client.patch(f"{BASE_URL}/api/admin/users/{student_id}/subscription", json={"subscription_active": True, "duration_days": 30})
check("Admin Toggle Subscription", resp)

# Manage Questions (Create)
q_payload = {
    "subject": "maths",
    "class_level": "10",
    "topic": "algebra",
    "question_text": "2+2?",
    "q_type": "mcq",
    "options": [{"label": "A", "text": "3"}, {"label": "B", "text": "4"}],
    "correct_index": 1,
    "positive_marks": 1.0,
    "difficulty": "easy"
}
resp = admin_client.post(f"{BASE_URL}/api/questions", json=q_payload)
q_data = check("Admin Create Question", resp)
qid = q_data["_id"]

# Manage Tests (Create, Publish)
test_payload = {
    "title": "E2E Test",
    "class_level": "10",
    "subject": "maths",
    "scheduled_date": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
    "start_time": "00:00",
    "end_time": "23:59",
    "question_ids": [qid],
    "is_published": True
}
resp = admin_client.post(f"{BASE_URL}/api/tests", json=test_payload)
test_data = check("Admin Create Test", resp)
tid = test_data["_id"]

# Student Take Test Flow
print("\n--- Student taking test ---")
resp = client.post(f"{BASE_URL}/api/tests/{tid}/start")
attempt_data = check("Student Start Test", resp)

resp = client.post(f"{BASE_URL}/api/tests/{tid}/submit", json={"answers": [{"question_id": qid, "selected_index": 1}]})
check("Student Submit Test", resp)

resp = client.get(f"{BASE_URL}/api/tests/{tid}/result")
check("Student View Result", resp)

resp = client.get(f"{BASE_URL}/api/tests/{tid}/leaderboard")
check("Student Leaderboard", resp)

resp = client.get(f"{BASE_URL}/api/tests/my-results")
check("Student My Results", resp)

# Admin View Attempts
print("\n--- Admin view attempts ---")
resp = admin_client.get(f"{BASE_URL}/api/tests/{tid}/attempts")
check("Admin View Test Attempts", resp)

# Manage Videos
video_payload = {
    "title": "E2E Video",
    "url": "https://youtube.com/watch?v=123",
    "subject": "maths",
    "class_level": "10"
}
resp = admin_client.post(f"{BASE_URL}/api/videos", json=video_payload)
video_data = check("Admin Create Video", resp)
vid = video_data["_id"]

resp = admin_client.put(f"{BASE_URL}/api/videos/{vid}", json={"title": "E2E Video Updated"})
check("Admin Edit Video", resp)

# Manage Flashcards
flash_payload = {
    "subject": "maths",
    "class_level": "10",
    "topic": "algebra",
    "front": "x",
    "back": "y"
}
resp = admin_client.post(f"{BASE_URL}/api/flashcards", json=flash_payload)
flash_data = check("Admin Create Flashcard", resp)
fid = flash_data["_id"]

resp = admin_client.put(f"{BASE_URL}/api/flashcards/{fid}", json={"front": "x2"})
check("Admin Edit Flashcard", resp)

# Manage Payments
resp = admin_client.get(f"{BASE_URL}/api/admin/payments")
check("Admin List Payments", resp)

print("\n--- Clean up ---")
admin_client.delete(f"{BASE_URL}/api/admin/users/{student_id}")
admin_client.delete(f"{BASE_URL}/api/questions/{qid}")
admin_client.delete(f"{BASE_URL}/api/tests/{tid}")
admin_client.delete(f"{BASE_URL}/api/videos/{vid}")
admin_client.delete(f"{BASE_URL}/api/flashcards/{fid}")

print("\nALL TESTS PASSED SUCCESSFULLY!")
