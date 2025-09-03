# FoodFlash - Crisis Simulation Project
## Instalación Rápida
### Opción 1: Con Docker (Recomendado)
```bash
docker-compose up -d
cd backend && npm install && npm run dev &
cd frontend && npm start
```
### Opción 2: Manual
```bash
createdb foodflash_dev
cd backend
npm install
npm run setup-db
npm run dev
cd frontend
npm start
```
## Para Crear Crisis
```bash
for i in {1..1000}; do
  curl -X POST http://localhost:3001/api/orders \
    -H "Content-Type: application/json" \
    -d '{"userId":1,"restaurantId":1,"items":[{"id":1,"name":"Pizza","quantity":1,"price":15.99}],"total":15.99,"paymentInfo":{"paymentMethodId":"test"}}' &
done
```
## URLs del Sistema
- **Frontend**: http://localhost:3000
- **Backend Health**: http://localhost:3001/health
- **API Health**: http://localhost:3001/api/health
