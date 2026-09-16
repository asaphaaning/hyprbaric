import React from 'react';
import PersistentBar from '../../components/PersistentBar';

export default function Root({children}) {
  return <PersistentBar>{children}</PersistentBar>;
}
