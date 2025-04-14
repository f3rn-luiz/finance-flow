# Finance Flow

![License](https://img.shields.io/badge/license-MIT-blue.svg) ![Version](https://img.shields.io/badge/version-v0.1.0-green.svg)

## Overview

Finance Flow is a comprehensive personal finance management application designed to give users complete control over their day-to-day financial activities. This full-stack solution enables users to manage income, expenses, credit card statements, multiple bank accounts, investments, and more in one centralized platform.

## Table of Contents

-   [Architecture](#architecture)
-   [Technologies](#technologies)
-   [Features](#features)
<!-- -   [Installation](#installation)
-   [Usage](#usage)
-   [API Documentation](#api-documentation)
-   [Database Schema](#database-schema) -->
-   [Contributing](#contributing)
-   [License](#license)
-   [Contact](#contact)

## Architecture

Finance Flow follows a three-tier architecture:

```
finance-flow/
├── app/     # Ionic/Angular frontend application
├── api/     # NestJS backend API with Prisma ORM
└── db/      # PostgreSQL database scripts
```

## Technologies

### Frontend (app/)

![Ionic](https://img.shields.io/badge/Ionic-3880FF?style=for-the-badge&logo=ionic&logoColor=white) ![Angular](https://img.shields.io/badge/Angular-DD0031?style=for-the-badge&logo=angular&logoColor=white) ![TailwindCSS](https://img.shields.io/badge/TailwindCSS-38B2AC?style=for-the-badge&logo=tailwind-css&logoColor=white) ![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?style=for-the-badge&logo=typescript&logoColor=white) ![HTML5](https://img.shields.io/badge/HTML5-E34F26?style=for-the-badge&logo=html5&logoColor=white) ![SCSS](https://img.shields.io/badge/SCSS-CC6699?style=for-the-badge&logo=sass&logoColor=white)

### Backend (api/)

![NestJS](https://img.shields.io/badge/NestJS-E0234E?style=for-the-badge&logo=nestjs&logoColor=white) ![Prisma](https://img.shields.io/badge/Prisma-2D3748?style=for-the-badge&logo=prisma&logoColor=white)

### Database (db/)

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-336791?style=for-the-badge&logo=postgresql&logoColor=white)

## Features

-   **Multi-account Management**: Track multiple bank accounts in one place
-   **Income & Expense Tracking**: Categorize and monitor all financial transactions
-   **Credit Card Management**: Track expenses and upcoming payments
-   **Investment Portfolio**: Monitor investment performance and returns
-   **Budget Planning**: Set budgets for different expense categories
-   **Financial Reports**: Visualize spending patterns with customizable reports
-   **Secure Authentication**: Protect your financial data with robust security
-   **Cross-platform Support**: Available on web, iOS, and Android

<!-- ## Installation

### Prerequisites

-   Node.js (v16+)
-   npm or yarn
-   PostgreSQL (v13+)
-   Ionic CLI

### Setup

1. Clone the repository

```bash
git clone https://github.com/f3rn-luiz/finance-flow.git
cd finance-flow
```

2. Set up the database

```bash
cd db
# Follow instructions in db/README.md
```

3. Set up the API

```bash
cd ../api
npm install
cp .env.example .env
# Configure your environment variables
npm run prisma:migrate
npm run start:dev
```

4. Set up the App

```bash
cd ../app
npm install
ionic serve
```

## Usage

After installation, you can:

1. Register a new account and log in
2. Add your bank accounts and credit cards
3. Begin tracking expenses and income
4. Set up budget categories
5. Monitor your financial flow through the dashboard

## API Documentation

API documentation is available via Swagger UI once the API is running:

```
http://localhost:3000/api/docs
```

## Database Schema

The database schema includes the following main entities:

-   Users
-   Accounts
-   Transactions
-   Categories
-   Budgets
-   Investments
-   Credit Cards

For detailed schema information, refer to `db/schema.prisma`. -->

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contact

Created by [@f3rn-luiz](https://github.com/f3rn-luiz)

Project Link: [https://github.com/f3rn-luiz/finance-flow](https://github.com/f3rn-luiz/finance-flow)
