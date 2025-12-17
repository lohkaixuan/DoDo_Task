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
    # 找到原来的任务
    existing_task = await Task.find_one(Task.flutter_id == flutter_id)
    if not existing_task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    # 情况 A: 刚刚完成 (Not Complete -> Complete) 
    is_just_completed = (
        task_data.status == "completed" and 
        existing_task.status != "completed"
    )
    
    # 情况 B: 刚刚取消 (Complete -> Not Complete) 
    is_just_uncompleted = (
        existing_task.status == "completed" and
        task_data.status != "completed"
    )

    # 更新所有字段
    await existing_task.update({"$set": task_data.dict(exclude={"id"})})
    # 3. 💰 算账时间
    coins_change = 0
    
    if is_just_completed:
        coins_change = 10
    elif is_just_uncompleted:
        coins_change = -10 # 👈 扣钱！

    # 只有当钱发生变化时才去骚扰 User 表
    if coins_change != 0:
        user = await User.find_one(User.email == existing_task.user_email)
        if user:
            user.coins += coins_change
            await user.save()
            print(f"⚖️ Balance updated: {coins_change} coins. Total: {user.coins}")

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