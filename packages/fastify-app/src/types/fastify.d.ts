import { StripeSync } from '@pretzelai/stripe-sync-engine'

declare module 'fastify' {
  interface FastifyInstance {
    stripeSync: StripeSync
  }
}
