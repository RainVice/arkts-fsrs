import { generatorParameters } from "./default";
import { SchedulingCard } from './scheduler'
import { FSRSParameters, Grade, Rating } from "./models";
import { get_fuzz_range } from "./help";
import { buffer } from '@kit.ArkTS';

// Ref: https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm#fsrs-v4
export const DECAY: number = -0.5;

// FACTOR = Math.pow(0.9, 1 / DECAY) - 1
export const FACTOR: number = 19 / 81;

export class FSRSAlgorithm {
  protected param: FSRSParameters;
  private readonly intervalModifier: number;
  protected seed?: string;

  constructor(param: Partial<FSRSParameters>) {
    this.param = generatorParameters(param);
    // Ref: https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm#fsrs-45
    // The formula used is : I(r,s)= (r^{\frac{1}{DECAY}-1}) \times \frac{s}{FACTOR}
    this.intervalModifier =
      (Math.pow(this.param.request_retention, 1 / DECAY) - 1) / FACTOR;
  }

  init_ds(s: SchedulingCard): void {
    s.again.difficulty = this.init_difficulty(Grade.Again);
    s.again.stability = this.init_stability(Grade.Again);
    s.hard.difficulty = this.init_difficulty(Grade.Hard);
    s.hard.stability = this.init_stability(Grade.Hard);
    s.good.difficulty = this.init_difficulty(Grade.Good);
    s.good.stability = this.init_stability(Grade.Good);
    s.easy.difficulty = this.init_difficulty(Grade.Easy);
    s.easy.stability = this.init_stability(Grade.Easy);
  }

  /**
   * 根据上次难度更新调度卡的难度和稳定性值，
   * 最后的稳定性，以及当前的可检索性。
   * @param {SchedulingCard} s 调度卡
   * @param {number} last_d难度
   * @param {number} last_s稳定性
   * @param可检索性 可检索性
   */
  next_ds(
    s: SchedulingCard,
    last_d: number,
    last_s: number,
    retrievability: number,
  ): void {
    s.again.difficulty = this.next_difficulty(last_d, Grade.Again);
    s.again.stability = this.next_forget_stability(
      last_d,
      last_s,
      retrievability,
    );
    s.hard.difficulty = this.next_difficulty(last_d, Grade.Hard);
    s.hard.stability = this.next_recall_stability(
      last_d,
      last_s,
      retrievability,
      Grade.Hard,
    );
    s.good.difficulty = this.next_difficulty(last_d, Grade.Good);
    s.good.stability = this.next_recall_stability(
      last_d,
      last_s,
      retrievability,
      Grade.Good,
    );
    s.easy.difficulty = this.next_difficulty(last_d, Grade.Easy);
    s.easy.stability = this.next_recall_stability(
      last_d,
      last_s,
      retrievability,
      Grade.Easy,
    );
  }

  /**
   * 使用的公式是：
   * S_0（G） = w_{G-1}
   * \max \{S_0,0.1\}
   * @param g 等级 （Anki 评级） [1.again，2.hard，3.good，4.easy]
   * @return稳定性（R=90%时间隔）
   */
  init_stability(g: Grade): number {
    return Math.max(this.param.w[g - 1], 0.1);
  }

  /**
   * 使用的公式是：
   * $$D_0（G） = w_4 - （G-3） \cdot w_5$$
   * $$\min \{\max \{D_0（G），1\}，10\}$$
   * 其中 D_0（3）=w_4 当第一个评级良好时。
   * @param {Grade} g Grade （Anki评分） [1.again，2.hard，3.good，4.easy]
   * @return {number} 难度 D \in [1,10]
   */
  init_difficulty(g: Grade): number {
    return this.numToFixedAndAbs(Math.min(
      Math.max(this.param.w[4] - (g - 3) * this.param.w[5], 1),
      10,
    ))
  }

  /**
   * 如果禁用了模糊测试或 IVL 小于 2.5，则返回原始间隔。
   * @param {number} ivl - 要模糊的间隔。
   * @param {number} 自上次审核以来 elapsed_days t 天
   * @param {number} enable_fuzz - 这会为新间隔增加一个小的随机延迟，以防止卡片粘在一起并始终在同一天进行审查。
   * @return {number} - 模糊间隔。
   **/
  apply_fuzz(ivl: number, elapsed_days: number, enable_fuzz?: boolean): number {
    if (!enable_fuzz || ivl < 2.5) return Math.round(ivl);
    const fuzz_factor = this.generateRandom(this.seed!)
    const ivls = get_fuzz_range(ivl, elapsed_days, this.param.maximum_interval,);
    return Math.floor(fuzz_factor * (ivls.max_ivl - ivls.min_ivl + 1) + ivls.min_ivl);
  }

  /**
   *裁判：
   * constructor（param： Partial<FSRSParameters>）
   * this.intervalModifier = 9 * （1 / this.param.request_retention - 1）;
   * @param {number} s - 稳定性（R=90% 时的间隔）
   * @param {number} 自上次审核以来 elapsed_days t 天
   * @param {number} enable_fuzz - 这会为新的间隔时间增加一个小的随机延迟，以防止卡片粘在一起并始终在同一天进行审查。
   */
  next_interval(
    s: number,
    elapsed_days: number,
    enable_fuzz: boolean = this.param.enable_fuzz,
  ): number {
    const newInterval = Math.min(
      Math.max(1, Math.round(s * this.intervalModifier)),
      this.param.maximum_interval,
    );
    return this.apply_fuzz(newInterval, elapsed_days, enable_fuzz);
  }

  /**
   * 使用的公式是：
   * $$next_d = D - w_6 \cdot （R - 2）$$
   * $$D^\prime（D，R） = w_5 \cdot D_0（2） +（1 - w_5） \cdot next_d$$
   * @param {number} d 难度 D \in [1,10]
   * @param {Grade} g Grade （Anki评分） [1.again，2.hard，3.good，4.easy]
   * @return {number} next_D
   */
  next_difficulty(d: number, g: Grade): number {
    const next_d = d - this.param.w[6] * (g - 3);
    return this.constrain_difficulty(
      this.mean_reversion(this.param.w[4], next_d),
    );
  }

  /**
   * 使用的公式是：
   * $$\min \{\max \{D_0,1\}，10\}$$
   * @param {number} 难度 D \in [1,10]
   */
  constrain_difficulty(difficulty: number): number {
    return Math.min(Math.max(this.numToFixedAndAbs(difficulty), 1), 10);
  }

  /**
   * 使用的公式是：
   * $$w_7 \cdot init +（1 - w_7） \cdot current$$
   * @param {number} 初始化 $$w_2 ： D_0（3） = w_2 + （R-2） \cdot w_3= w_2$$
   * @param {number} 当前 $$D - w_6 \cdot （R - 2）$$
   * @return {number} 难度
   */
  mean_reversion(init: number, current: number): number {
    return this.numToFixedAndAbs(this.param.w[7] * init + (1 - this.param.w[7]) * current)
  }

  /**
   * 使用的公式是：
   * $$S^\prime_r（D，S，R，G） = S\cdot（e^{w_8}\cdot （11-D）\cdot S^{-w_9}\cdot（e^{w_10\cdot（1-R）}-1）\cdot w_15（如果 G=2） \cdot w_16（如果 G=4）+1）$$
   * @param {number} d 难度 D \in [1,10]
   * @param {number} s 稳定性（R=90% 时的间隔）
   * @param {number} r 可检索性（召回概率）
   * @param {Grade} g Grade （评分[0.again，1.hard，2.good，3.easy]）
   * @return {number} S^\prime_r 召回后的新稳定性
   */
  next_recall_stability(d: number, s: number, r: number, g: Grade): number {
    const hard_penalty = Rating.Hard === g.valueOf() ? this.param.w[15] : 1;
    const easy_bound = Rating.Easy === g.valueOf() ? this.param.w[16] : 1;
    return this.numToFixedAndAbs(
      s *
        (1 +
          Math.exp(this.param.w[8]) *
            (11 - d) *
          Math.pow(s, -this.param.w[9]) *
            (Math.exp((1 - r) * this.param.w[10]) - 1) *
            hard_penalty *
            easy_bound)
    )
  }

  /**
   * 使用的公式是：
   * $$S^\prime_f（D，S，R） = w_11\cdot D^{-w_{12}}\cdot （（S+1）^{w_{13}}-1） \cdot e^{w_{14}\cdot（1-R）}.$$
   * @param {number} d 难度 D \in [1,10]
   * @param {number} s 稳定性（R=90% 时的间隔）
   * @param {number} r 可检索性（召回概率）
   * @return {number} S^\prime_f 遗忘后的新稳定性
   */
  next_forget_stability(d: number, s: number, r: number): number {
    return this.numToFixedAndAbs(
      this.param.w[11] *
      Math.pow(d, -this.param.w[12]) *
        (Math.pow(s + 1, this.param.w[13]) - 1) *
      Math.exp((1 - r) * this.param.w[14])
    )
  }

  /**
   * 使用的公式是：
   * $$R（t，S） = （1 + FACTOR \times \frac{t}{9 \cdot S}）^{DECAY}，$$
   * @param {number} 自上次审核以来 elapsed_days t 天
   * @param {number} 稳定性 稳定性（R=90% 时的间隔）
   * @return {number} r 可检索性（召回概率）
   */
  forgetting_curve(elapsed_days: number, stability: number): number {
    return this.numToFixedAndAbs(Math.pow(1 + (FACTOR * elapsed_days) / stability, DECAY))
  }


  numToFixedAndAbs(num: number, length: number = 8) {
    return Math.abs(parseFloat(num.toFixed(length)))
  }


  generateRandom(seed: string, min: number = 0, max: number = 1): number {
    let _seed = parseInt(buffer.from(seed).toString('hex'), 16)
    // 使用线性同余生成器（LCG）作为随机数生成器
    // 这里使用的是一个简单的LCG公式：Xn+1 = (a * Xn + c) mod m
    // 其中，a, c, m是事先选定的参数，这里使用常见的数值
    const a = 1664525;
    const c = 1013904223;
    const m = 2**32;
    // 用种子更新随机数生成器的内部状态
    _seed = (a * _seed + c) % m;
    // 将生成的数值映射到指定的范围[min, max]
    return min + (_seed / m) * (max - min);
  }
}
