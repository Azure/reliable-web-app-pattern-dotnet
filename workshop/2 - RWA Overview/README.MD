# 2 - Reliable Web App Pattern - .NET Overview

The reliable web app pattern (or RWA) is a set of principles that helps developers successfully migrate web applications to the cloud. It provides implementation guidance built on the Azure Well-Architected Framework. The pattern focuses on the minimal changes you need to make to ensure the success of your web app in the cloud.

In this workshop series, we're going to run through the principles and show how to apply them to your web applications.

## Enterprise web app cloud journey

Imagine a web application's evolution in the cloud as a journey. Each step in the journey has different goals. The reliable web app pattern is designed to help you take the first step in the journey. You may only need to "lift and shift" or replatform your application to the cloud, and do so with a minimal amount of changes. The reliable web app pattern helps you do that.

![Enterprise web app cloud journey](../images/2-RWA%20Overview/enterprise-web-app-cloud-journey.png)

Further along in the journey, you may want to refactor your application to take advantage of cloud-native features and then optimize it for scale and performance.

But first, let's explore what it means to converge in the cloud and create an application that's reliable with minimal changes in your existing investment.

## Pattern of patterns

That's not to say that the reliable web app pattern is simpilistic. _It is not_. 

It's a pattern of patterns. Each pattern provides prescriptive guidance on how to build a specific aspect of a reliable web application. You can use them together or separately.

The image below shows just some of the considerations that you'll need to take into account when converging to the cloud and the reliable web app pattern provides guidance on those. In fact, the reliable web app pattern builds on real-world tested technologies and techniques, like the Azure Well-Architected Framework to produce the set of patterns that you'll learn about in the image below.

![Pattern of patterns](../images/2-RWA%20Overview/pattern-of-patterns.png)

## Objectives

The objectives of the reliable web app pattern are straightforward. It's designed to help you migrate to the cloud with good cloud practices:

![Objectives](../images/2-RWA%20Overview/objectives.png)

## The Five Pillars

The reliable web app pattern is built off of 5 pillars. Each pillar is a set of patterns that are derived from both the Azure Well-Architected Framework and 12-factor app methodology.

![The Five Pillars](../images/2-RWA%20Overview/the-five-pillars.png)

## Next Steps

Now that your application is up and running, it’s time to shift our attention towards optimizing the cost of our Azure deployment.

[Part 3 - Cost Optimization](../3%20-%20Cost%20Optimization/README.md)

In case your application is not yet deployed, please revisit the development and Azure tooling sections of this workshop. Ensure all the necessary tools are properly set up and your application is running smoothly before proceeding.

[Part 1 - Tooling Setup](../Part%201%20-%20Tooling/README.md)


