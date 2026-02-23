/*
Copyright 2026 The Kubernetes resource-state-metrics Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package internal

import (
	"fmt"
	"strconv"
	"strings"
)

// Label directly associates a label name with its value expression.
type Label struct {
	Name  string `yaml:"name"`
	Value string `yaml:"value"`
}

// MetricType represents a single time series.
type MetricType struct {
	Labels   []Label      `yaml:"labels"`
	Value    string       `yaml:"value"`
	Resolver ResolverType `yaml:"resolver,omitempty"`
}

func writeMetricTo(writer *strings.Builder, g, v, k, resolvedValue string, resolvedLabelKeys, resolvedLabelValues []string) error {
	resolvedLabelKeys, resolvedLabelValues = appendGVKLabels(resolvedLabelKeys, resolvedLabelValues, g, v, k)
	if err := writeLabels(writer, resolvedLabelKeys, resolvedLabelValues); err != nil {
		return err
	}

	return writeValue(writer, resolvedValue)
}

func appendGVKLabels(keys, values []string, g, v, k string) ([]string, []string) {
	keys = append(keys, "group", "version", "kind")
	values = append(values, g, v, k)

	return keys, values
}

func writeLabels(writer *strings.Builder, keys, values []string) error {
	if len(keys) == 0 {
		return nil
	}

	separator := "{"
	for i := range keys {
		writer.WriteString(separator)
		writer.WriteString(keys[i])
		writer.WriteString("=\"")
		n, err := strings.NewReplacer("\\", `\\`, "\n", `\n`, "\"", `\"`).WriteString(writer, values[i])
		if err != nil {
			return fmt.Errorf("error writing metric after %d bytes: %w", n, err)
		}
		writer.WriteString("\"")
		separator = ","
	}
	writer.WriteString("}")

	return nil
}

func writeValue(writer *strings.Builder, value string) error {
	writer.WriteByte(' ')
	floatVal, err := strconv.ParseFloat(value, 64)
	if err != nil {
		return fmt.Errorf("error parsing metric value %q as float64: %w", value, err)
	}
	n, err := fmt.Fprintf(writer, "%f", floatVal)
	if err != nil {
		return fmt.Errorf("error writing (float64) metric value after %d bytes: %w", n, err)
	}
	writer.WriteByte('\n')

	return nil
}
