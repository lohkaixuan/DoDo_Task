from fastapi import APIRouter, HTTPException, Body
from typing import List
from app.models.user import User
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
    # 1) 找任务
    existing_task = await Task.find_one(Task.flutter_id == flutter_id)
    if not existing_task:
        raise HTTPException(status_code=404, detail="Task not found")

    # Debug logs
    print(f"🔍 Checking Task: {existing_task.title}")
    print(f"   --- Old Status: {existing_task.status}")
    print(f"   --- New Status: {task_data.status}")

    # 2) 判断 coins 变化
    is_just_completed = (task_data.status == "completed" and existing_task.status != "completed")
    is_just_uncompleted = (existing_task.status == "completed" and task_data.status != "completed")

    coins_change = 10 if is_just_completed else (-10 if is_just_uncompleted else 0)

    print(f"   --- Is Just Completed? {is_just_completed}")
    print(f"   --- Coins Change: {coins_change}")
    print(f"   --- Looking for user email: {existing_task.user_email}")

    # 3) 更新任务本身（先更新任务）
    await existing_task.update({"$set": task_data.model_dump(exclude={"id"})})

    # 4) 若需要，更新用户 coins
    new_coins = None
    if coins_change != 0:
        user = await User.find_one(User.email == existing_task.user_email)
        if not user:
            raise HTTPException(status_code=404, detail="User not found for coin update")

        user.coins = int(user.coins or 0) + int(coins_change)
        await user.save()
        new_coins = user.coins
        print("✅ COIN UPDATE:", user.email, "change=", coins_change, "now=", user.coins)

    # 5) 回传给 Flutter（关键：回 coins）
    return {
        "message": "Updated",
        "coins_change": coins_change,
        "coins": new_coins,   # 前端用这个直接更新 UI
    }

# 4. 删除任务
@router.delete("/tasks/{flutter_id}", tags=["Tasks"])
async def delete_task(flutter_id: str):
    existing_task = await Task.find_one(Task.flutter_id == flutter_id)
    if existing_task:
        await existing_task.delete()
        return {"message": "Deleted"}
    raise HTTPException(status_code=404, detail="Task not found")