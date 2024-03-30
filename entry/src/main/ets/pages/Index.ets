import { Card, createEmptyCard, fsrs, FSRS, Grade, ReviewLog } from '@rv/ts-fsrs';

@Entry
@Component
struct Index {
  @State card: Card = createEmptyCard();
  @State f: FSRS = fsrs();
  @State logs: ReviewLog[] = []
  @State cards: Card[] = []

  @State now : Date = new Date()


  handleClick(grade:Grade){
    const log = this.f.repeat(this.card,new Date())[grade].log;
    this.card = this.f.repeat(this.card,new Date())[grade].card;

    this.logs.unshift(log);
    this.cards.unshift(this.card);
  }


  build() {
    Row() {
      Column() {
        Row(){
          //export enum Grade {
          //   Again = 1,
          //   Hard = 2,
          //   Good = 3,
          //   Easy = 4,
          // }
          Button("重来")
            .onClick(() => {
              this.handleClick(Grade.Again)
            })
          Button("困难")
            .onClick(() => {
              this.handleClick(Grade.Hard)
            })
          Button("一般")
            .onClick(() => {
              this.handleClick(Grade.Good)
            })
          Button("简单")
            .onClick(() => {
              this.handleClick(Grade.Easy)
            })
        }

        Text(this.now.toString())

        List(){
          ForEach(this.cards, (item: Card) => {
            ListItem(){
              Text(item.due.toTimeString() + " " + item.last_review?.toTimeString())
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
    }
    .height('100%')
  }
}