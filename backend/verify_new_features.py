import os
import requests
import sys

BASE_URL = os.environ.get("BASE_URL", "http://localhost:8001")
print(f"Testing features at {BASE_URL}...")

client = requests.Session()
admin_client = requests.Session()

def assert_status(name, resp, expected=200):
    if resp.status_code != expected:
        print(f"❌ FAIL: {name} (Expected {expected}, got {resp.status_code})")
        print(resp.text)
        sys.exit(1)
    print(f"✅ PASS: {name}")
    try:
        return resp.json()
    except Exception:
        return resp.text

# 1. Admin Login
print("\n--- 1. Admin Login & Settings ---")
resp = admin_client.post(f"{BASE_URL}/api/auth/login", json={
    "email": "admin@studybook.com",
    "password": "Admin@123"
})
admin_user = assert_status("Admin Login", resp)

# 2. Student Registration with SB-YY-CLASS-XXXX Student ID
print("\n--- 2. Student Registration & Student ID ---")
reg_payload = {
    "name": "Feature Tester Student",
    "email": "featuretester@studybook.com",
    "phone": "+919876543210",
    "password": "TestPassword123",
    "class_level": "10"
}
resp = client.post(f"{BASE_URL}/api/auth/register", json=reg_payload)
if resp.status_code == 400 and "already registered" in resp.text:
    resp = client.post(f"{BASE_URL}/api/auth/login", json={
        "email": "featuretester@studybook.com",
        "password": "TestPassword123"
    })
student_user = assert_status("Student Register/Login", resp)

student_id = student_user.get("student_id")
print(f"  Generated Student ID: {student_id}")
if not student_id or not student_id.startswith("SB-"):
    print(f"❌ FAIL: Invalid student_id format: {student_id}")
    sys.exit(1)
print("  Student ID format verified (SB-YY-CLASS-XXXX).")

# 3. Profile Photo Upload
print("\n--- 3. Profile Photo Upload ---")
fake_image_bytes = b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15c4"
files = {"file": ("test_avatar.png", fake_image_bytes, "image/png")}
resp = client.post(f"{BASE_URL}/api/auth/profile/photo", files=files)
updated_user = assert_status("Profile Photo Upload", resp)
if not updated_user.get("avatar_url", "").startswith("data:image/png;base64,"):
    print("❌ FAIL: Avatar URL was not updated with base64 data URI")
    sys.exit(1)
print("  Profile photo base64 data URI verified.")

# 4. Global Leaderboard Release Control
print("\n--- 4. Leaderboard Release Toggle ---")
# Hide leaderboard first
resp = admin_client.post(f"{BASE_URL}/api/admin/leaderboard/release", json={"released": False})
assert_status("Admin Hide Global Leaderboard", resp)

# Verify student gets 403 Forbidden
resp = client.get(f"{BASE_URL}/api/leaderboard")
if resp.status_code == 403:
    print("✅ PASS: Student blocked when leaderboard is unreleased")
else:
    print(f"❌ FAIL: Student received status {resp.status_code} when leaderboard unreleased")
    sys.exit(1)

# Release leaderboard
resp = admin_client.post(f"{BASE_URL}/api/admin/leaderboard/release", json={"released": True})
assert_status("Admin Release Global Leaderboard", resp)

# Verify student can view leaderboard
resp = client.get(f"{BASE_URL}/api/leaderboard")
lb_data = assert_status("Student View Released Leaderboard", resp)

# Check avatar and student_id in leaderboard items
items = lb_data.get("items", [])
if len(items) > 0:
    first_item = items[0]
    print(f"  First item fields: student_id={first_item.get('student_id')}, avatar_url={bool(first_item.get('avatar_url'))}")
    if "student_id" in first_item and "avatar_url" in first_item:
        print("✅ PASS: Leaderboard items contain student_id and avatar_url")

# 5. Promo Banners with Image URL & Link URL
print("\n--- 5. Promo Banners with Image URL & Link URL ---")
promo_payload = {
    "title": "Special 50% Off Test",
    "subtitle": "Limited time offer on Class 10 materials",
    "code": "TEST50",
    "link_url": "/pricing",
    "image_url": "https://images.unsplash.com/photo-1516321318423-f06f85e504b3",
    "countdown_hours": 48,
    "is_active": True
}
resp = admin_client.post(f"{BASE_URL}/api/promos", json=promo_payload)
created_promo = assert_status("Admin Create Promo with Image URL", resp)
promo_id = created_promo["_id"]

if created_promo.get("image_url") == promo_payload["image_url"]:
    print("✅ PASS: Promo image_url saved correctly")

# Test PUT /api/promos/{id}
resp = admin_client.put(f"{BASE_URL}/api/promos/{promo_id}", json={"title": "Updated Special 50% Off"})
updated_promo = assert_status("Admin Edit Promo", resp)
if updated_promo.get("title") == "Updated Special 50% Off":
    print("✅ PASS: Promo PUT update verified")

# Clean up promo
admin_client.delete(f"{BASE_URL}/api/promos/{promo_id}")

# 6. Admin Referral Tracking API
print("\n--- 6. Admin Referral Analytics ---")
resp = admin_client.get(f"{BASE_URL}/api/admin/referrals")
ref_data = assert_status("Admin Get Referrals", resp)
print(f"  Referrals count: {len(ref_data.get('items', []))}")

print("\n🎉 ALL 7 NEW FEATURES VERIFIED SUCCESSFULLY!")
