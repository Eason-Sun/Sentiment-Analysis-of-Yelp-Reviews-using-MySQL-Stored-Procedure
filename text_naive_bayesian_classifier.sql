-- Table dataSet contains some review comments and their according stars.
drop table if exists dataSet;
create temporary table dataSet (`sentence` text, stars int, result text);
-- Table formatedDataSet formats the review comments from dataSet.
drop table if exists formatedDataSet;
create temporary table formatedDataSet(`sentence` text, `result` text);
-- Table trainingSet is the random split of formatedDataSet with ratio=0.9.
drop table if exists trainingSet;
create temporary table trainingSet(`sentence` text, `result` text);
-- Table testingSet is the random split of formatedDataSet with ratio=0.1.
drop table if exists testingSet;
create temporary table testingSet(`sentence` text, `result` text);
-- Table words contains individual words splited from the comment.
drop table if exists words;
create temporary table words(`word` text, `result` text);
-- Table prob is the probability distribution of individual words group by their classes.
drop table if exists prob;
create temporary table prob(`word` text, `result` text, `ratio` double, key `word_index` (`word`(255)));
-- Table prediction stores testing comments with their true and predicted classes as well as the confidence levels.
drop table if exists prediction;
create temporary table prediction(`sentence` text, `result` text, `predResult` text, `confidence` decimal(8,6));
-- Below variables stores total number of words for each class.
set @v_numOfGoodReview=0.0;
set @v_numOfBadReview=0.0;

-- Criterion: good comments mean their star=5 and bad comments mean their star<=2.
insert into dataSet (`sentence`, `stars`) select text, stars from review where (stars=5 and rand()<.005) or (stars<=2 and rand()<0.01);
update dataSet set result = case when stars<=2 then "bad" else "good" end;
alter table dataSet drop column stars;
-- The comments are formated so that all words from the sentence are separated by commas.
insert into formatedDataSet(`sentence`, `result`) SELECT REGEXP_REPLACE(sentence, '[^a-zA-Z0-9\']+', ',', 1), result from dataSet;
drop table dataSet;

-- Randomly split the data into training data and testing data with testing ratio of 10%.
insert into trainingSet(`sentence`, `result`) select sentence, result from formatedDataSet where rand()<0.9;
insert into testingSet(`sentence`, `result`) select * from formatedDataSet where (sentence, result) not in (select * from trainingSet);
drop table formatedDataSet;

-- This procedure splits words from given sentence and inserts them into table words.
drop procedure if exists getWordsFromSentence;
delimiter //
create procedure getWordsFromSentence(in sentence text, in result text)
begin
declare v_wordCount int default 0;
select (length(sentence) - length(replace(sentence, ',', ''))) into v_wordCount;
while v_wordCount > 0 do
insert into words(`word`, `result`) select substring_index(sentence, ',', 1), result;
set sentence = substring_index(sentence, ',', -v_wordCount);
set v_wordCount = v_wordCount - 1;
end while;
end //
delimiter ;

-- This procedure generates the probability distribution of each word in both classes.
drop procedure if exists probGen;
delimiter //
create procedure probGen()
begin
select count(*) + 1 from words where result = 'good' into @v_numOfGoodReview;
select count(*) + 1 - @v_numOfGoodReview from words into @v_numOfBadReview;
insert into prob(`word`, `result`, `ratio`) select word, 'good',(count(*)+1)/@v_numOfGoodReview from words where result='good' group by word;
insert into prob(`word`, `result`, `ratio`) select word, 'bad',(count(*)+1)/@v_numOfBadReview from words where result='bad' group by word;
end //
delimiter ;

-- This procedure uses cursor to itearte through sentences from trainingSet and make the split, then it apply probGen to get a overall probability distribution.
drop procedure if exists train;
delimiter //
create procedure train()
begin
declare v_isFinished int default 0;
declare v_sentence text default '';
declare v_result text default '';
declare sentenceCursor cursor for select sentence, result from trainingSet;
declare continue handler for not found set v_isFinished = 1;
open sentenceCursor;
getSentence: loop
fetch sentenceCursor into v_sentence, v_result;
if v_isFinished = 1 then leave getSentence; 
end if;
call getWordsFromSentence(v_sentence, v_result);
end loop getSentence;
close sentenceCursor;
call probGen();
delete from words;
drop table trainingSet;
select "Training Finished!" as `Current Process`;
end //
delimiter ;

-- This function returns probability distribution by given word and its class.
drop function if exists findProb;
delimiter //
create function findProb(v_word text, class text) returns double deterministic 
begin
declare tmp double default 0;
select ratio into tmp from prob where word=v_word and result=class;
return (tmp);
end //
delimiter ;

-- This procedure use Naive Bayesian Classifer to predict classes by given sentence, and results are stored in table prediction.
drop procedure if exists predictSentence;
delimiter //
create procedure predictSentence(in v_sentence text, in result text)
begin
declare dummy_prob_good double default (1/@v_numOfGoodReview);
declare dummy_prob_bad double default (1/@v_numOfBadReview);
declare ln_prob_good double default 0;
declare ln_prob_bad double default 0;
call getWordsFromSentence(v_sentence, result);
select sum(ln(case when findProb(word,"good")=0 then dummy_prob_good else findProb(word,"good") end)) into ln_prob_good from words;
select sum(ln(case when findProb(word,"bad")=0 then dummy_prob_bad else findProb(word,"bad") end)) into ln_prob_bad from words;
-- select ln_prob_good,ln_prob_bad;
if ln_prob_good > ln_prob_bad then
insert into prediction(`sentence`, `result`, `predResult`, `confidence`) select v_sentence, result, "good", ln_prob_bad/(ln_prob_good+ln_prob_bad);
else 
insert into prediction(`sentence`, `result`, `predResult`, `confidence`) select v_sentence, result, "bad", ln_prob_good/(ln_prob_good+ln_prob_bad);
end if;
delete from words;
end//
delimiter ;

-- This procedure iterates through all sentences from testing data and use above procedure to make predictions.
drop procedure if exists predict;
delimiter //
create procedure predict()
begin
declare v_isFinished int default 0;
declare v_sentence text default '';
declare v_result text default '';
declare sentenceCursor cursor for select sentence, result from testingSet;
declare continue handler for not found set v_isFinished = 1;
delete from prediction;
open sentenceCursor;
getSentence: loop
fetch sentenceCursor into v_sentence, v_result;
if v_isFinished = 1 then leave getSentence;
end if;
call predictSentence(v_sentence, v_result);
end loop getSentence;
close sentenceCursor;
select "Prediction Finished!" as `Current Process`;
end //
delimiter ;

-- This procedure provides the metrics (Accuracy, Precision, Recall) for evaluating the performance of Naive Bayesian Classifer. 
drop procedure if exists evaluate;
delimiter //
create procedure evaluate()
begin
declare truePositive int default 0;
declare falsePositive int default 0;
declare trueNegative int default 0;
declare falseNegative int default 0;
select count(case when result="good" and predResult="good" then 1 end) into truePositive from prediction;
select count(case when result="bad" and predResult="good" then 1 end) into falsePositive from prediction;
select count(case when result="bad" and predResult="bad" then 1 end) into trueNegative from prediction;
select count(case when result="good" and predResult="bad" then 1 end) into falseNegative from prediction;
select (truePositive+trueNegative)/(truePositive+trueNegative+falsePositive+falseNegative) as `Accuracy`, truePositive/(truePositive+falsePositive) as `Precision`, truePositive/(truePositive+falseNegative) as `Recall`;
end //
delimiter ;

-- call train;
-- call predict;
-- call evaluate;
