from fastapi import APIRouter, HTTPException, Body
from typing import List
from app.models.models import Task

router = APIRouter()

# 1. 创建任务 (Sync from Flutter)
@router.post("/tasks", tags=["Tasks"], response_model=Task)
async def create_task(task: Task):
    # 前端传来的 JSON 会自动映射成 Task 对象
    # 如果数据库里已经有了这个 flutter_id，我们可以选择更新或者忽略
    # 这里演示直接插入
    await task.insert()
    return task

# 2. 获取用户的所有任务
@router.get("/tasks/{user_email}", tags=["Tasks"], response_model=List[Task])
async def get_user_tasks(user_email: str):
    tasks = await Task.find(Task.user_email == user_email).to_list()
    return tasks

# 3. 更新任务 (当你在 Flutter 修改了任务)
@router.put("/tasks/{flutter_id}", tags=["Tasks"])
async def update_task(flutter_id: str, task_data: Task):
    # 1. 找原来的任务
    existing_task = await Task.find_one(Task.flutter_id == flutter_id)
    if not existing_task:
        print(f"❌ Task not found: {flutter_id}") # Debug Log
        raise HTTPException(status_code=404, detail="Task not found")

    # Debug Logs: 打印出来看看状态到底是个啥
    print(f"🔍 Checking Task: {existing_task.title}")
    print(f"   --- Old Status: {existing_task.status}")
    print(f"   --- New Status: {task_data.status}")

    # 情况 A: 刚刚完成
    is_just_completed = (
        task_data.status == "completed" and 
        existing_task.status != "completed"
    )
    
    # 情况 B: 刚刚取消
    is_just_uncompleted = (
        existing_task.status == "completed" and
        task_data.status != "completed"
    )
    
    print(f"   --- Is Just Completed? {is_just_completed}")

    # 更新数据库
    await existing_task.update({"$set": task_data.dict(exclude={"id"})})
    
    # 💰 算账
    coins_change = 0
    if is_just_completed:
        coins_change = 10
    elif is_just_uncompleted:
        coins_change = -10

    print(f"   --- Coins Change: {coins_change}")

    if coins_change != 0:
        # 找用户
        print(f"   --- Looking for user email: {existing_task.user_email}")
        user = await User.find_one(User.email == existing_task.user_email)
        
        if user:
            user.coins += coins_change
            await user.save()
            print(f"✅ User found! New Balance: {user.coins}")
        else:
            print(f"❌ User NOT found for email: {existing_task.user_email}")

    return {
        "message": "Updated", 
        "coins_earned": coins_change
    }

# 4. 删除任务
@router.delete("/tasks/{flutter_id}", tags=["Tasks"])
async def delete_task(flutter_id: str):
    existing_task = await Task.find_one(Task.flutter_id == flutter_id)
    if existing_task:
        await existing_task.delete()
        return {"message": "Deleted"}
    raise HTTPException(status_code=404, detail="Task not found")