import { buildEntitySchema } from '@vyapti/core';
import { Custome } from './custome.entity';
import { Customer2 } from './customer_2.entity';
import { Customer3 } from './customer_3.entity';

export const entitySchemas = [
    buildEntitySchema(Custome),
    buildEntitySchema(Customer2),
    buildEntitySchema(Customer3),
];
