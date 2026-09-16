Student Management API - FastAPI version
Topic 11-2: API Testing with Postman & Newman - 504070 SOA (Fall 2026)

Chay:
    pip install fastapi uvicorn "pyjwt>=2.8" pydantic
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
    http://127.0.0.1:8000
    http://127.0.0.1:8000/docs