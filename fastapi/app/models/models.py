# app/models.py
from datetime import datetime
from sqlalchemy import (
    Column, String, Integer, Float, Enum, Date, DateTime, Boolean,
    ForeignKey, UniqueConstraint, Index
)
from sqlalchemy.orm import declarative_base, relationship
from sqlalchemy.types import JSON

Base = declarative_base()

# --- 2) tasks ---------------------------------------------------------------
TaskCategory = Enum('Academic','Personal','Private', name='task_category')
TaskStatus   = Enum('pending','done','overdue', name='task_status')

class Task(Base):
    __tablename__ = "tasks"
    task_id = Column(String, primary_key=True)          # UUID
    user_id = Column(String, index=True, nullable=False)
    title = Column(String, nullable=False)
    category = Column(TaskCategory, nullable=False)
    priority = Column(Integer, default=2)               # 1=High,2=Med,3=Low
    estimated_time = Column(Integer)                    # minutes
    due_date = Column(Date)
    status = Column(TaskStatus, default='pending')
    completed_at = Column(DateTime)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

Index('ix_tasks_user_due', Task.user_id, Task.due_date)

# --- 3) pets ---------------------------------------------------------------
PetMood = Enum('happy','sleepy','concerned','idle', name='pet_mood')

class Pet(Base):
    __tablename__ = "pets"
    pet_id = Column(String, primary_key=True)           # UUID
    user_id = Column(String, index=True, nullable=False, unique=True)  # 1 pet/user
    skin_id = Column(String)                            # FK -> skins (optional)
    energy = Column(Integer, default=0)                 # -100..100
    mood = Column(PetMood, default='idle')
    xp = Column(Integer, default=0)
    level = Column(Integer, default=1)
    coins = Column(Integer, default=0)
    equipped_items = Column(JSON, default=list)         # accessories/backgrounds

# --- 4) pet_actions --------------------------------------------------------
ActionCategory = Enum('academic','coding','wellness','general', name='action_category')

class PetAction(Base):
    __tablename__ = "pet_actions"
    action_id = Column(String, primary_key=True)        # e.g. study_read
    category = Column(ActionCategory, nullable=False)
    base_coin = Column(Integer, default=1)
    energy_delta = Column(Integer, default=0)
    surprise_chance = Column(Float, default=0.0)        # 0..1
    default_anim = Column(String)
    props = Column(JSON, default=dict)

# --- 5) pet_reactions ------------------------------------------------------
class PetReaction(Base):
    __tablename__ = "pet_reactions"
    reaction_id = Column(String, primary_key=True)      # celebrate/cheer/concern/idle
    trigger = Column(Enum('start','during','complete','overdue','streak', name='reaction_trigger'))
    animation = Column(String)
    sound = Column(String)
    dialogue = Column(JSON, default=list)               # array[str]

# --- 6) rewards ------------------------------------------------------------
RewardType = Enum('skin','background','item', name='reward_type')
RewardRarity = Enum('common','rare','legendary', name='reward_rarity')

class Reward(Base):
    __tablename__ = "rewards"
    reward_id = Column(String, primary_key=True)
    type = Column(RewardType, nullable=False)
    rarity = Column(RewardRarity, nullable=False)
    cost = Column(Integer, nullable=False)
    requirements = Column(JSON, default=dict)           # e.g. {"streak":7}

# --- 7) events (append-only behavior stream) -------------------------------
EventType = Enum(
    'task_start','task_complete','overdue','break_start','break_end',
    'hydrate','sleep_log','focus_start','focus_tick','shop_purchase',
    'app_open','app_idle','emotion_text','emotion_voice',
    name='event_type'
)

class Event(Base):
    __tablename__ = "events"
    event_id = Column(String, primary_key=True)
    user_id = Column(String, index=True, nullable=False)
    ts = Column(DateTime, default=datetime.utcnow, index=True)
    type = Column(EventType, nullable=False)
    context = Column(JSON, default=dict)                # {task_id, duration, score, ...}

Index('ix_events_user_ts', Event.user_id, Event.ts)

# --- 8) mood_logs ----------------------------------------------------------
MoodLabel = Enum('positive','neutral','negative','anxious','tired', name='mood_label')
MoodSource = Enum('user_text','user_slider','voice_infer','text_infer', name='mood_source')

class MoodLog(Base):
    __tablename__ = "mood_logs"
    mood_id = Column(String, primary_key=True)
    user_id = Column(String, index=True, nullable=False)
    ts = Column(DateTime, default=datetime.utcnow, index=True)
    source = Column(MoodSource, nullable=False)
    label = Column(MoodLabel, nullable=False)
    confidence = Column(Float, default=1.0)
    notes = Column(String)

# --- 9) focus_sessions -----------------------------------------------------
class FocusSession(Base):
    __tablename__ = "focus_sessions"
    session_id = Column(String, primary_key=True)
    user_id = Column(String, index=True, nullable=False)
    task_id = Column(String, ForeignKey('tasks.task_id'), nullable=True)
    started_at = Column(DateTime, nullable=False)
    ended_at = Column(DateTime)                          # null if ongoing
    planned_minutes = Column(Integer)
    actual_minutes = Column(Integer)                     # derived
    interruptions = Column(Integer, default=0)
    quality_score = Column(Float)                        # 0..1

Index('ix_focus_user_start', FocusSession.user_id, FocusSession.started_at)

# --- 10) usage_stats_daily -------------------------------------------------
class UsageStatsDaily(Base):
    __tablename__ = "usage_stats_daily"
    user_id = Column(String, primary_key=True)
    date = Column(Date, primary_key=True)
    tasks_completed = Column(Integer, default=0)
    overdue_count = Column(Integer, default=0)
    avg_priority_completed = Column(Float)
    total_focus_minutes = Column(Integer, default=0)
    breaks_taken = Column(Integer, default=0)
    hydration_count = Column(Integer, default=0)
    sleep_minutes = Column(Integer, default=0)
    mood_negative_count = Column(Integer, default=0)
    late_night_usage = Column(Integer, default=0)

# --- 11) stress_risk_scores -----------------------------------------------
ScoreWindow = Enum('daily','rolling_72h', name='score_window')

class StressRiskScore(Base):
    __tablename__ = "stress_risk_scores"
    score_id = Column(String, primary_key=True)
    user_id = Column(String, index=True, nullable=False)
    ts = Column(DateTime, default=datetime.utcnow, index=True)
    window = Column(ScoreWindow, default='daily')
    score = Column(Float, nullable=False)               # 0..100
    signals = Column(JSON, default=dict)                # explainability

# --- 12) interventions -----------------------------------------------------
InterventionKind = Enum(
    'micro_break','water','breathe','plan_tiny_step',
    'reschedule','lighten_load','bedtime_prompt','gratitude','reach_out',
    name='intervention_kind'
)
Outcome = Enum('completed','skipped','snoozed', name='intervention_outcome')

class Intervention(Base):
    __tablename__ = "interventions"
    intervention_id = Column(String, primary_key=True)
    user_id = Column(String, index=True, nullable=False)
    ts = Column(DateTime, default=datetime.utcnow, index=True)
    kind = Column(InterventionKind, nullable=False)
    reason = Column(String)
    payload = Column(JSON, default=dict)
    accepted = Column(Boolean, default=None)            # tri-state
    outcome = Column(Outcome)
    followup_ts = Column(DateTime)

# --- 13) triggers (feature-flag rules) ------------------------------------
TriggerAction = Enum('create_intervention','adjust_rewards', name='trigger_action')

class Trigger(Base):
    __tablename__ = "triggers"
    trigger_id = Column(String, primary_key=True)       # e.g. overdue_triage
    active = Column(Boolean, default=True)
    condition = Column(JSON, default=dict)              # rule expression
    action = Column(TriggerAction, nullable=False)
    cooldown_minutes = Column(Integer, default=120)
    parameters = Column(JSON, default=dict)
