# Business scenario

This guide demonstrates how principles from the [Well-Architected
Framework](https://docs.microsoft.com/azure/architecture/framework/)
and [Twelve-Factor Applications](https://12factor.net/) can be applied
to migrate and modernize a legacy, line-of-business (LOB) web app to the
cloud. A reference architecture is included to showcase a production
ready solution which can be easily deployed for learning and
experimentation.

The reference scenario discussed in this guide is for Relecloud
Concerts, a fictional company that sells concert tickets. Their website,
currently employee-facing, is an illustrative example of an LOB
eCommerce application historically used by call center operators to buy
tickets on behalf of their offline (telephone) customers. Relecloud has
experienced increased sales volume over the last quarter with continued
increases projected, and senior leadership has decided to invest more in
direct customer sales online instead of expanding call center capacity.

Their call center employee website is a monolithic ASP.NET application
with a Microsoft SQL Server database which suffers from common legacy
challenges including extended timelines to build and ship new features
and difficulty scaling different components of the application under
higher load. Relecloud\'s near-term objective is to modernize the
application to sustain additional volume while maturing development team
practices for modern development and operations. Intermediate and
longer-term goals include opening the application directly to online 
customers through multiple web and mobile experiences, improving
availability targets, significantly reducing the time required to
deliver new features to the application, and scaling different
components of the system independently to handle traffic spikes
without compromising security. They have chosen Azure as the
destination for their application due to its robust global platform and
tremendous managed service capabilities that will support Relecloud's
growth objectives for years to come.

The reference that follows demonstrates the first phase of their
journey - a modernized LOB web application that has improved
reliability, security, performance, and more mature operational
practices at a predictable cost. This phase also provides a foundation
upon which they will achieve their longer-term objectives in later
phases. The following solution diagram shows the reference architecture
that we'll discuss for the rest of the guide.

# Next Step
- [Read the reference architecture](reliable-web-app.md)