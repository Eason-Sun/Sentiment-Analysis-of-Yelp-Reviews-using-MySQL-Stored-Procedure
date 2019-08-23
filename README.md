# Sentiment-Analysis-of-yelp-reviews

## Dataset:
https://www.yelp.ca/dataset/challenge

## Environment:
MySQL 8.0 required

## Objective:
The goal of this project is to train a sentiment classifier using reviews from yelp dataset. This classifier can later be generalized for any unseen sentences/paragraphs so that it could accurately classify polarity of a given text and extract subjective information, such as positive or negative emotion.

## Implementation:
Bayesian Classifier is a well-known machine learning algorithm for textual classification. It is aimed to give the class that yields maximum posterior. In this particular application, we implement a Naïve Bayesian Classifier with the assumption of independence of word probabilities and ordering given any class.

### Train data:
The Review sentences.

### Train labels:
The yelp reviews are classified based on stars. If it’s 5 stars, it’s marked as good review. If it’s less than 2 stars, it’s regarded as bad review

### Training vs. Testing:
The data is randomly splited into training data and testing data with testing ratio of 10%.

![Capture](https://user-images.githubusercontent.com/29167705/63559788-5c9e9480-c521-11e9-8009-32abd371e054.JPG)

### Laplace smoothing:
In this implementation, Laplace smoothing is applied for both training and testing dataset in order to solve zero probability problem. Considering of machine precision for the floating points, we transform conditional probabilities to log-space to avoid dealing with extremely tiny numbers.

## Evaluation:
![ECE 656 Project Report](https://user-images.githubusercontent.com/29167705/63559747-24975180-c521-11e9-8728-7369b5c89d34.jpg)

I also made up some fake reviews and let the classifier to figure out:
![Capture](https://user-images.githubusercontent.com/29167705/63559924-db93cd00-c521-11e9-9878-b1b848b4beb6.JPG)

And the results:
![Capture](https://user-images.githubusercontent.com/29167705/63559956-03833080-c522-11e9-8029-c72a68bbbfef.JPG)


## Open Problem:
In general, words from a sentence are correlated in some sense. For instance,
Pr (“fantastic” | C = good review) = 0.7 and Pr (“delicious” | C = good review) = 0.8, but
Pr (“fantastic”, “delicious” | good review) does not necessarily equal to 0.8*0.7=0.56, and it usually higher than that, since Pr (“fantastic” | C = good review, “delicious”) is not equal to zero. Theoretically, this might degrade the performance to some extent. In reality, for binary classification, it turns out that this algorithm performs pretty well in terms of accuracy and time efficiency.
