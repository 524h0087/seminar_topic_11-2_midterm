import time
from datetime import datetime, timedelta, timezone
from typing import Optional

import jwt
from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, EmailStr, Field

# --------------------------------------------------------------------------
# Config (demo only)
# --------------------------------------------------------------------------
JWT_SECRET = "SOA-Topic11-2-Demo-Secret-Key-For-Postman-Newman-CI-CD-2026"
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_MINUTES = 60

DEMO_USERNAME = "admin"
DEMO_PASSWORD = "admin123"

app = FastAPI(
    title="Student Management API",
    description="Demo REST API cho seminar Topic 11-2: API Testing with Postman & Newman",
    version="1.0.0",
)

security = HTTPBearer()

# --------------------------------------------------------------------------
# Models
# --------------------------------------------------------------------------
class LoginRequest(BaseModel):
    username: str
    password: str


class LoginResponse(BaseModel):
    token: str
    tokenType: str = "Bearer"
    username: str


class StudentIn(BaseModel):
    name: str = Field(..., min_length=1)
    email: EmailStr
    major: Optional[str] = None
    gpa: Optional[float] = Field(None, ge=0.0, le=10.0)


class Student(StudentIn):
    id: int


# --------------------------------------------------------------------------
# "Database" Simulate DB
# --------------------------------------------------------------------------
students_db: dict[int, Student] = {}
next_id = 1


def seed_data():
    global next_id
    seed = [
        StudentIn(name="Nguyen Van A", email="vana@student.edu.vn", major="Software Engineering", gpa=8.5),
        StudentIn(name="Tran Thi B", email="thib@student.edu.vn", major="Computer Science", gpa=9.0),
        StudentIn(name="Le Van C", email="vanc@student.edu.vn", major="Information Systems", gpa=7.8),
    ]
    for s in seed:
        students_db[next_id] = Student(id=next_id, **s.dict())
        next_id += 1


seed_data()

# --------------------------------------------------------------------------
# JWT helpers
# --------------------------------------------------------------------------
def create_token(username: str) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": username,
        "iat": now,
        "exp": now + timedelta(minutes=JWT_EXPIRE_MINUTES),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)) -> str:
    token = credentials.credentials
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        return payload["sub"]
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")


# --------------------------------------------------------------------------
# Auth endpoints
# --------------------------------------------------------------------------
@app.post("/api/auth/login", response_model=LoginResponse)
def login(payload: LoginRequest):
    if payload.username == DEMO_USERNAME and payload.password == DEMO_PASSWORD:
        token = create_token(payload.username)
        return LoginResponse(token=token, username=payload.username)
    raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid username or password")


# --------------------------------------------------------------------------
# Student CRUD endpoints
# --------------------------------------------------------------------------
@app.get("/api/students", response_model=list[Student])
def get_all_students(_: str = Depends(verify_token)):
    return list(students_db.values())


@app.get("/api/students/{student_id}", response_model=Student)
def get_student(student_id: int, _: str = Depends(verify_token)):
    student = students_db.get(student_id)
    if not student:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Student not found with id {student_id}")
    return student


@app.post("/api/students", response_model=Student, status_code=status.HTTP_201_CREATED)
def create_student(payload: StudentIn, _: str = Depends(verify_token)):
    global next_id
    student = Student(id=next_id, **payload.dict())
    students_db[next_id] = student
    next_id += 1
    return student


@app.put("/api/students/{student_id}", response_model=Student)
def update_student(student_id: int, payload: StudentIn, _: str = Depends(verify_token)):
    if student_id not in students_db:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Student not found with id {student_id}")
    updated = Student(id=student_id, **payload.dict())
    students_db[student_id] = updated
    return updated


@app.delete("/api/students/{student_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_student(student_id: int, _: str = Depends(verify_token)):
    if student_id not in students_db:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Student not found with id {student_id}")
    del students_db[student_id]
    return None


# --------------------------------------------------------------------------
# Health check
# --------------------------------------------------------------------------
@app.get("/actuator/health")
def health():
    return {"status": "UP", "timestamp": time.time()}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)