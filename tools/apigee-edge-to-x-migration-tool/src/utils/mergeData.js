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

/**
 * Checks if the provided argument is a valid object.
 * 
 * @param {any} obj - The argument to check.
 * @returns {boolean} - Returns true if the argument is an object, false otherwise.
 */
function isObject(obj) {
  return obj !== null && typeof obj === 'object' && !Array.isArray(obj);
}

/**
 * Recursively merges two objects, with optional precedence determination.
 * 
 * @param {Object} target - The target object to merge into.
 * @param {Object} source - The source object to merge from.
 * @param {boolean} [targetPrecedence=true] - Determines if the target should take precedence.
 * @returns {Object|null} - The merged object, or null if both are identical.
 */
function mergeDeep(target, source, targetPrecedence = true) {
  if (!isObject(target) || !isObject(source)) {
    return source;
  }

  // Check if both target and source are identical
  if (JSON.stringify(target) === JSON.stringify(source)) {
    return null; // Return null if they are the same
  }

  Object.keys(source).forEach(key => {
    const targetValue = target[key];
    const sourceValue = source[key];

    if (Array.isArray(targetValue) && Array.isArray(sourceValue)) {
      target[key] = mergeArrays(targetValue, sourceValue, targetPrecedence);
    } else if (isObject(targetValue) && isObject(sourceValue)) {
      target[key] = mergeDeep({ ...targetValue }, sourceValue, targetPrecedence); // Use spread operator for shallow copy
    } else {
      target[key] = targetPrecedence && targetValue !== undefined ? targetValue : sourceValue;
    }
  });

  return target;
}

/**
 * Merges two arrays, resolving conflicts based on object properties.
 * 
 * @param {Array} targetArray - The target array to merge into.
 * @param {Array} sourceArray - The source array to merge from.
 * @param {boolean} targetPrecedence - Determines if the target should take precedence.
 * @returns {Array} - The merged array.
 */
function mergeArrays(targetArray, sourceArray, targetPrecedence) {
  const mergedArray = [...targetArray]; // Create a copy to avoid mutation

  sourceArray.forEach(sourceItem => {
    if (isObject(sourceItem)) {
      const conflictIndex = mergedArray.findIndex(targetItem =>
        isObject(targetItem) && targetItem.name === sourceItem.name
      );

      if (conflictIndex === -1) {
        mergedArray.push(sourceItem);
      } else {
        mergedArray[conflictIndex] = targetPrecedence ? mergedArray[conflictIndex] : sourceItem;
      }
    } else {
      if (!mergedArray.includes(sourceItem)) {
        mergedArray.push(sourceItem);
      }
    }
  });

  return mergedArray;
}

/**
 * Function to find differences between two objects.
 * 
 * @param {Object} target - The target object.
 * @param {Object} source - The source object.
 * @returns {Array} - An array of differences with key, source and target values.
 */
function findDeviations(target, source) {
  const differences = [];

  // Function to compare objects and collect differences
  function compareObjects(obj1, obj2, path = '') {
    const allKeys = new Set([...Object.keys(obj1), ...Object.keys(obj2)]);

    allKeys.forEach(key => {
      const fullPath = path ? `${path}.${key}` : key;
      const value1 = obj1[key];
      const value2 = obj2[key];

      if (isObject(value1) && isObject(value2)) {
        compareObjects(value1, value2, fullPath);
      } else if (Array.isArray(value1) && Array.isArray(value2)) {
        if (JSON.stringify(value1) !== JSON.stringify(value2)) {
          differences.push({ deviations: fullPath, source: value2, target: value1 });
        }
      } else if (value1 !== value2) {
        differences.push({ deviations: fullPath, source: value2, target: value1 });
      }
    });
  }

  // Compare target and source objects
  compareObjects(target, source);

  return differences.length > 0 ? differences : null;
}

/**
 * Removes specified keys from an object.
 * 
 * @param {Object} obj - The object from which to remove keys.
 * @param {Array} keysToRemove - An array of keys to remove.
 * @returns {Object} - A new object with specified keys removed.
 */
function dropKeys(obj, keysToRemove) {
  return Object.fromEntries(
    Object.entries(obj).filter(([key]) => !keysToRemove.includes(key))
  );
}

/**
 * Main function to merge two data sets after removing specified metadata keys.
 * 
 * @param {Object} target - The target object.
 * @param {Object} source - The source object.
 * @param {boolean} [targetPrecedence=true] - Determines if the target should take precedence in conflicts.
 * @returns {Object|null} - The merged object, or null if both are identical.
 */
export default async function mergeData(target, source, targetPrecedence = true) {
  // Metadata keys that should be excluded during merging
  const keysToRemove = ["createdAt", "createdBy", "lastModifiedAt", "lastModifiedBy"];

  const cleanedSource = dropKeys(source, keysToRemove);
  const cleanedTarget = dropKeys(target, keysToRemove);
  const finalResult = { deviations: '', mergedData: '' };

  // Check if cleaned objects are identical
  if (JSON.stringify(cleanedTarget) === JSON.stringify(cleanedSource)) {
    return finalResult
  }
  finalResult.source = cleanedSource;
  finalResult.target = cleanedTarget;
  finalResult.mergedData = mergeDeep(cleanedTarget, cleanedSource, targetPrecedence);
  finalResult.deviations = findDeviations(cleanedTarget, cleanedSource);
  return finalResult;
}