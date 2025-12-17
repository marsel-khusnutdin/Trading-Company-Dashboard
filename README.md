## Dashboard Overview

This dashboard was created using **demo data** defined in the `data_creation` file.  
The file contains the full database schema and table creation logic.

The dashboard is organized into three main sections: **Onboarding**, **Transactions**, and **Trading Volume**.

🔗 **Published Dashboard:**  
[View the dashboard here](https://public.tableau.com/views/CompanyOverview_17644470068300/CompanyOverview?:language=en-US&publish=yes&:sid=&:display_count=n&:origin=viz_share_link)

> **Note:** Please use full-screen mode to ensure the dashboard fits properly on the screen.


<img width="1343" height="677" alt="Main page" src="https://github.com/user-attachments/assets/d0da08d6-674b-4cf4-a7a2-ede0fb4bd7c9" />


### Onboarding
The onboarding section visualizes the user funnel using a mirrored horizontal bar chart. This approach was used as a workaround, since this visualization type is not natively available in Tableau. Each funnel stage is supported by KPI cards showing total counts and conversion rates.

Although line charts are typically preferred for trend analysis, monthly performance is displayed using bar sparklines with month-over-month (MoM) indicators. This format works well given the limited number of months in the dataset.

### Transactions
The transactions section includes KPI cards covering key deposit and withdrawal metrics. Monthly trends are shown using line charts, while a conditional-color bar chart highlights periods of net positive versus net negative cash flows.

### Trading Volume
In the trading volume section, KPI cards summarize overall volumes, and a trend line illustrates volume changes over time. Volume by country is displayed using horizontal bar charts to make cross-country comparisons easier.

For the **VPM (Volume per Client Age)** metric, a heatmap is used to highlight high- and low-intensity markets. A boxplot showing volume distribution per user is included to help identify outliers that may influence VPM.

### Additional Features
Because the task focuses on country-level analysis, country-specific detail pages for onboarding and deposits were proposed and implemented, with navigation links included. On the deposits detail page, a **Top N / Bottom N country selector** was added to provide deeper insights.

<img width="1326" height="552" alt="Deposit Details" src="https://github.com/user-attachments/assets/49f355df-e293-4bee-a7f4-c8ff56229426" />

<img width="1348" height="552" alt="Onboarding stgaes" src="https://github.com/user-attachments/assets/5aaf512d-fb04-44d3-b184-f6af921d48d3" />
