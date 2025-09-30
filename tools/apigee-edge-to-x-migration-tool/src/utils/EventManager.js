/**
 * Copyright 2025 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

class EventManager {
  static _listeners = {};

  /**
   * 
   * @param {*} eventName 
   * @returns 
   */
  static _getEventId(eventName) {
    const eventId = eventName.toLowerCase();

    if (typeof this._listeners[eventId] === 'undefined' || !Array.isArray(this._listeners[eventId])) {
      this._listeners[eventId] ??= [];
    }

    return eventId;
  }

  /**
   * Trigger an event and call listeners in the order they were registerd.
   *
   * @param {*} eventName 
   * @param  {...any} eventArgs 
   */
  static async trigger(eventName, ...eventArgs) {
    const eventId = this._getEventId(eventName);

    for (const listener of this._listeners[eventId]) {
      await listener(...eventArgs);
    }
  }

  /**
   * Register a listener for a given event name.
   *
   * @param {*} eventName 
   * @param {*} handler 
   */
  static listen(eventName, handler) {
    if (typeof handler !== 'function') {
      throw new Error(`Handler for ${eventName} event is not a function.`);
    }

    const eventId = this._getEventId(eventName);

    this._listeners[eventId].push(handler);
  }
}

export default EventManager;