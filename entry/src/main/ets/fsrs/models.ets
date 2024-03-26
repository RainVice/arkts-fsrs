import { FsrsDate } from './help';

export type StateType = "New" | "Learning" | "Review" | "Relearning";

export enum State {
  New = 0,
  Learning = 1,
  Review = 2,
  Relearning = 3,
}

export type RatingType = "Manual" | "Again" | "Hard" | "Good" | "Easy";

export enum Rating {
  Manual = 0,
  Again = 1,
  Hard = 2,
  Good = 3,
  Easy = 4,
}

// export type Grade = Rating

// type ExcludeManual<T> = Exclude<T, Rating.Manual>;

// export type Grade = ExcludeManual<Rating>;


export enum Grade {
  Again = 1,
  Hard = 2,
  Good = 3,
  Easy = 4,
}


export interface ReviewLog {
  rating: Rating; // 复习的评级（手动变更，重来，困难，良好，容易）
  state: State; // 复习的状态（新卡片、学习中、复习中、重新学习中）
  due: FsrsDate; // 上次的调度日期
  stability: number; // 复习前的记忆稳定性
  difficulty: number; // 复习前的卡片难度
  elapsed_days: number; // 自上次复习以来的天数
  last_elapsed_days: number; // 上次复习的间隔天数
  scheduled_days: number; // 下次复习的间隔天数
  review: FsrsDate; // 复习的日期
}

export interface RecordLogItem {
  card: Card;
  log: ReviewLog;
}
;

// export type RecordLog = {
//   [key in Grade]: RecordLogItem;
// };

export type RecordLog = Record<Grade, RecordLogItem>

export interface Card {
  due: FsrsDate; // 卡片下次复习的日期
  stability: number; // 记忆稳定性
  difficulty: number; // 卡片难度
  elapsed_days: number; // 自上次复习以来的天数
  scheduled_days: number; // 下次复习的间隔天数
  reps: number; // 卡片被复习的总次数
  lapses: number; // 卡片被遗忘或错误记忆的次数
  state: State; // 卡片的当前状态（新卡片、学习中、复习中、重新学习中）
  last_review?: FsrsDate; // 最近的复习日期（如果适用）
}

export interface CardInput extends Omit<Card, "state" | "due" | "last_review"> {
  state: StateType | State; // 卡片状态（新建、学习、复习、重新学习）
  due: DateInput; // 期限
  last_review?: DateInput | null; // 上次审核日期（可选）
}

export type DateInput = FsrsDate | number | string;

export interface ReviewLogInput
extends Omit<ReviewLog, "rating" | "state" | "due" | "review"> {
  rating: RatingType | Rating; // 评论评分（再次，困难，良好，简单）
  state: StateType | State; // 卡片状态（新建、学习、复习、重新学习）
  due: DateInput; // 期限
  review: DateInput; // 上次审查日期
}

export interface FSRSParameters {
  request_retention: number;
  maximum_interval: number;
  w: number[];
  enable_fuzz: boolean;
}

export interface RescheduleOptions {
  enable_fuzz?: boolean;
  dateHandler?: (date: FsrsDate) => DateInput;
}
;