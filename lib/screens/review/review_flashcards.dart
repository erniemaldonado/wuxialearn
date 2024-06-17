import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hsk_learner/data_model/word_item.dart';
import 'package:hsk_learner/sql/review_sql.dart';
import 'package:hsk_learner/sql/sql_helper.dart';
import '../../utils/styles.dart';
import '../settings/preferences.dart';
import 'flashcard.dart';
class ReviewFlashcards extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> hskList;
  final Function update;
  final String type;
  final int deckSize;
  const ReviewFlashcards({Key? key, required this.hskList, required this.update, required this.type, required this.deckSize}) : super(key: key);

  @override
  State<ReviewFlashcards> createState() => _ReviewFlashcardsState();
}

class _ReviewFlashcardsState extends State<ReviewFlashcards> {
  bool lastPage = false;
  bool wasClicked = false;
  bool showPinyin = Preferences.getPreference("show_pinyin_by_default_in_review");
  bool showHint = false;
  bool showShowHint = false;
  final PageController _pageController = PageController(initialPage: 0);
  int offset = 0;

  late Future<List<Map<String, dynamic>>> reviewList;

  @override
  void initState() {
    reviewList = widget.hskList;
    super.initState();
    setShowHint();
    setLanguage();
  }

  setShowHint() async {
    List<WordItem> wordList = createWordList(await widget.hskList);
    showShowHint = wordList[0].hanzi.length > 1;
  }

  nextButtonCallback(){
    setState(() {
      wasClicked = true;
    });
  }

  Future<List<Map<String, dynamic>>> appendElements(Future<List<Map<String, dynamic>>> listFuture, Future<List<Map<String, dynamic>>> elementsToAdd) async {
    final list = await listFuture;
    final list2 = await elementsToAdd;
    final list3 = [...list, ...list2];
    return list3;
  }

  Duration getRandomDuration(Duration min, Duration max) {
    int minMilliseconds = min.inMilliseconds;
    int maxMilliseconds = max.inMilliseconds;
    Random rnd = Random();
    var range = (maxMilliseconds - minMilliseconds);
    return Duration(milliseconds:minMilliseconds + rnd.nextInt(range));
  }

  answerButtonCallBack(int id) {
    return(int value) async {
      int stat = value == 0 || value == 1 ? 0:1;
      SQLHelper.insertStat(value: stat, id: id);
      DateTime dateTime = switch(value){
        0 => DateTime.now().add(const Duration(minutes: 1)),
        1 => DateTime.now().add(const Duration(minutes: 6)),
        2 => DateTime.now().add(const Duration(hours: 12)),
        3 => DateTime.now().add(const Duration(days: 4)),
        4 => DateTime.now().add(getRandomDuration(const Duration(days: 10), const Duration(days: 30))),
        _ => DateTime.now(),
      };
      final int time  = dateTime.toUtc().millisecondsSinceEpoch ~/ 1000;
      SQLHelper.updateReview(id: id, time: time);
      widget.update();
      /*
      still needs some thought on what we should do here
      if(widget.type == "SRS"){
        print("we are here");
        final newList =  ReviewSql.getSrsReview(deckSize: 10);
        setState(() {
          reviewList = newList;
        });}
       */
      if (_pageController.hasClients) {
        if (lastPage) {
          Navigator.pop(context);
        } else {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
      }
      setState(() {
        wasClicked = false;
        showHint = false;
      });
    };
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  FlutterTts flutterTts = FlutterTts();
  setLanguage() async{
    await flutterTts.setLanguage("zh-CN");
  }

  Future speak(String text) async{
    await flutterTts.speak(text);
  }
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text("Review"),
      ),
      child: SafeArea(
        child: Column(
          children: [
            FutureBuilder<List<Map<String, dynamic>>>(
                future: reviewList,
                builder: (BuildContext context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
                  if (snapshot.hasData) {
                    List<WordItem> wordList = createWordList(snapshot.data!);
                    return Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Visibility(
                                visible: showShowHint,
                                child: TextButton(
                                    onPressed: (){
                                      setState(() {
                                        showHint = !showHint;
                                      });
                                    },
                                    child: showHint?
                                    const Text("Hide Hint")
                                        :const Text("Show Hint")
                                ),
                              ),
                              TextButton(
                                  onPressed: (){
                                    setState(() {
                                      showPinyin = !showPinyin;
                                    });
                                  },
                                  child: showPinyin?
                                    const Text("Hide Pinyin")
                                    :const Text("Show Pinyin")
                              ),
                            ],
                          ),
                          Expanded(
                              child: PageView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                controller: _pageController,
                                itemCount: wordList.length,
                                onPageChanged: (index) {
                                  if (index + 1 == wordList.length) {
                                    lastPage = true;
                                  }
                                  setState(() {
                                    showShowHint = wordList[index].hanzi.length > 1;
                                  });
                                },
                                itemBuilder: (context, pageIndex) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                          child: FlashCard(
                                            showFrontSide: !wasClicked,
                                            front: Column(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Visibility(
                                                        visible: showPinyin,
                                                          child: Text(
                                                              wordList[pageIndex].pinyin,
                                                              style: const TextStyle(fontSize: 20, color: Colors.black54),
                                                          )
                                                      ),
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          Visibility(
                                                            maintainState: true,
                                                            maintainSize: true,
                                                            maintainAnimation: true,
                                                            visible: false,
                                                            child: IconButton(
                                                                onPressed: () {
                                                                  speak(wordList[pageIndex].hanzi);
                                                                },
                                                                icon: const Icon(Icons.volume_up)
                                                            ),
                                                          ),
                                                          Text(
                                                            wordList[pageIndex].hanzi,
                                                            style: const TextStyle(fontSize: 40, color: Colors.black),
                                                          ),
                                                          Visibility(
                                                            maintainState: true,
                                                            maintainSize: true,
                                                            maintainAnimation: true,
                                                            visible: showPinyin,
                                                            child: IconButton(
                                                                onPressed: () {
                                                                  speak(wordList[pageIndex].hanzi);
                                                                },
                                                                icon: const Icon(Icons.volume_up)
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      Visibility(
                                                          visible: showHint,
                                                          child: Text(
                                                            wordList[pageIndex].literal.join(" + "),
                                                            style: const TextStyle(fontSize: 20, color: Colors.black54),
                                                          )
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                               _ShowNextCardButton(callback: nextButtonCallback),
                                              ],
                                            ),
                                            back: Column(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Text(wordList[pageIndex].pinyin, style: const TextStyle(fontSize: 25, color: Colors.black),),
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          Visibility(
                                                            maintainState: true,
                                                            maintainSize: true,
                                                            maintainAnimation: true,
                                                            visible: false,
                                                            child: IconButton(
                                                                onPressed: () {
                                                                  speak(wordList[pageIndex].hanzi);
                                                                },
                                                                icon: const Icon(Icons.volume_up)
                                                            ),
                                                          ),
                                                          Text(
                                                            wordList[pageIndex].hanzi,
                                                            style: const TextStyle(fontSize: 40, color: Colors.black),
                                                          ),
                                                          Visibility(
                                                            maintainState: true,
                                                            maintainSize: true,
                                                            maintainAnimation: true,
                                                            visible: true,
                                                            child: IconButton(
                                                                onPressed: () {
                                                                  speak(wordList[pageIndex].hanzi);
                                                                },
                                                                icon: const Icon(Icons.volume_up)
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      Text(wordList[pageIndex].translation, style: const TextStyle(fontSize: 25, color: Colors.black),),
                                                      Visibility(
                                                          visible: showHint,
                                                          child: Text(
                                                            wordList[pageIndex].literal.join(" + "),
                                                            style: const TextStyle(fontSize: 20, color: Colors.black54),
                                                          )
                                                      ),
                                                   ]
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.all(15.0),
                                                  child: SingleChildScrollView(
                                                    scrollDirection: Axis.horizontal,
                                                    child: _AnswerButton(
                                                        callback: answerButtonCallBack(wordList[pageIndex].id)
                                                    ),
                                                  ),
                                                )
                                              ],
                                            )
                                          ),
                                      ),
                                    ],
                                  );
                                },
                              )
                          ),
                        ],
                      ),
                    );
                  }
                  else{return const Center(child: CircularProgressIndicator());}
                }
            ),
          ],
        ),
      ),
    );
  }
}

class _ShowNextCardButton extends StatelessWidget {
  final Function() callback;
  const _ShowNextCardButton({Key? key, required this.callback,}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => {
                callback(),
              },
              child: const Text("Show"),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  final Function(int value) callback;
  const _AnswerButton({Key? key, required this.callback,}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        TextButton(
          onPressed: (){callback(0);},
          child: const Column(
            children: [
              Text("< 1 min"),
              Text("Again")
            ],
          )
        ),
        TextButton(
            onPressed: (){callback(1);},
            child: const Column(
              children: [
                Text("< 6 min"),
                Text("Hard")
              ],
            )
        ),
        TextButton(
            onPressed: (){callback(2);},
            child: const Column(
              children: [
                Text("< 12 hrs"),
                Text("Good")
              ],
            )
        ),
        TextButton(
            onPressed: (){callback(3);},
            child: const Column(
              children: [
                Text("4 days"),
                Text("Easy")
              ],
            )
        ),
        TextButton(
            onPressed: (){callback(4);},
            child: const Column(
              children: [
                Text("10-30 days"),
                Text("Perfect")
              ],
            )
        ),
      ],
    );
  }
}
