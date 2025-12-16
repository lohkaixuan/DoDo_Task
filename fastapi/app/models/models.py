from typing import List, Optional
from datetime import datetime
from enum import Enum
from beanie import Document
from pydantic import BaseModel, Field

# --- Enums (对应 Flutter 的 Enum) ---
class TaskType(str, Enum):
    singleDay = "singleDay"
    ranged = "ranged"

class TaskStatus(str, Enum):
    notStarted = "notStarted"
    inProgress = "inProgress"
    completed = "completed"
    late = "late"
    archived = "archived"

class PriorityLevel(str, Enum):
    low = "low"
    medium = "medium"
    high = "high"
    urgent = "urgent"

class RepeatGranularity(str, Enum):
    none = "none"
    minute = "minute"
    hour = "hour"
    day = "day"

class SubTaskStatus(str, Enum):
    notStarted = "notStarted"
    inProgress = "inProgress"
    completed = "completed"
    skipped = "skipped"

# --- Nested Models (对应 Flutter 的嵌套类) ---
class FocusTimerPrefs(BaseModel):
    pomodoroMinutes: int = 25
    shortBreakMinutes: int = 5
    longBreakEvery: int = 4
    notificationsEnabled: bool = True

class NotificationPrefs(BaseModel):
    remindBeforeStart: bool = True
    remindBeforeStartOffsetMinutes: int = 1440 # Duration 转为分钟存
    remindOnStart: bool = True
    remindBeforeDue: bool = True
    remindBeforeDueOffsetMinutes: int = 120
    remindOnDue: bool = True
    repeatWhenToday: RepeatGranularity = RepeatGranularity.none
    repeatInterval: int = 1
    dailyHour: Optional[int] = None
    dailyMinute: Optional[int] = None

class SubTask(BaseModel):
    id: str
    title: str
    estimatedMinutes: Optional[int] = None
    dueDate: Optional[datetime] = None
    status: SubTaskStatus = SubTaskStatus.notStarted
    focusMinutesSpent: int = 0

# --- Main Document (数据库存的主体) ---
class Task(Document):
    # 这里我们用 flutter_id 存前端生成的 UUID，方便对应
    flutter_id: str 
    user_email: str  # 必须标记是谁的任务
    
    title: str
    description: Optional[str] = None
    type: TaskType
    
    dueDateTime: Optional[datetime] = None
    startDate: Optional[datetime] = None
    dueDate: Optional[datetime] = None
    timezone: str = 'Asia/Kuala_Lumpur'
    
    category: Optional[str] = None
    tags: List[str] = []
    
    status: TaskStatus = TaskStatus.notStarted
    subtasks: List[SubTask] = []
    
    focusPrefs: FocusTimerPrefs = Field(default_factory=FocusTimerPrefs)
    notify: NotificationPrefs = Field(default_factory=NotificationPrefs)
    
    priority: PriorityLevel = PriorityLevel.medium
    important: bool = True
    estimatedMinutes: Optional[int] = None
    
    createdAt: datetime = Field(default_factory=datetime.now)
    updatedAt: datetime = Field(default_factory=datetime.now)

    class Settings:
        name = "tasks"
        
    class Config:
        # 允许把 Enum 存为 string
        use_enum_values = True