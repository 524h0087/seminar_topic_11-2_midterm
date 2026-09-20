Student Management API - FastAPI version
Topic 11-2: API Testing with Postman & Newman - 504070 SOA (Fall 2026)

Automated Build phase:
    powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1

Build script behavior:
    1. Check Python and requirements.txt
    2. Create or reuse .venv
    3. Upgrade pip
    4. Install dependencies from requirements.txt
    5. Verify the FastAPI app can be imported
    6. Run pip check

Chay:
    pip install -r requirements.txt
    uvicorn main:app --reload --port 8080

Endpoints:
    POST   /api/auth/login          -> đăng nhập, trả JWT token (admin / admin123)
    GET    /api/students            -> lấy danh sách sinh viên      (cần Bearer token)
    GET    /api/students/{id}       -> lấy 1 sinh viên              (cần Bearer token)
    POST   /api/students            -> tạo sinh viên (201)          (cần Bearer token)
    PUT    /api/students/{id}       -> cập nhật sinh viên           (cần Bearer token)
    DELETE /api/students/{id}       -> xóa sinh viên (204)          (cần Bearer token)
    GET    /actuator/health         -> health check (public, dùng cho CI/CD)

Open your browser:
    http://127.0.0.1:8080
    http://127.0.0.1:8080/docs
