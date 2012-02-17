/* This file is part of VoltDB.
 * Copyright (C) 2008-2010 VoltDB L.L.C.
 *
 * VoltDB is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * VoltDB is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with VoltDB.  If not, see <http://www.gnu.org/licenses/>.
 */

package org.voltdb.jni;

import org.apache.log4j.Level;
import org.apache.log4j.Logger;
import org.voltdb.utils.VoltLoggerFactory;

/**
 * Only a subset of log4j loggers are made available for use with in the EE. A long is passed in to the EE
 * with the log level of all the EE specific loggers that are made available into the EE. Since it takes
 * three bits to represent six log levels (and ALL/OFF) there can be up to 20 loggers. This allows the log level checks to be performed
 * in the EE without a JNI call back to Java.
 */
public class EELoggers {
    /*
     * Encoding for various log settings that will fit in 3 bits
     */
    public static final int all = 0;
    public static final int trace = 1;
    public static final int debug = 2;
    public static final int info = 3;
    public static final int warn = 4;
    public static final int error = 5;
    public static final int fatal = 6;
    public static final int off = 7;

    /*
     * The order of the loggers in this array determines the order their
     * log level is encoded into the long and the order they will be read
     * in the backend.
     */
    public static final Logger loggers[] = new Logger[] {
        Logger.getLogger("SQL", VoltLoggerFactory.instance()),
        Logger.getLogger("HOST", VoltLoggerFactory.instance())
    };

    /**
     * Return a long containing the encoded status of every log level for the relevant loggers.
     * @return A long containing log levels for all the loggers available in the EE
     */
    public final static long getLogLevels() {
        long logLevels = 0;
        for (int ii = 0; ii < loggers.length; ii++) {
            final int level = loggers[ii].getEffectiveLevel().toInt();
            switch (level) {
            case Level.TRACE_INT:
                logLevels |= trace << (ii * 3);
                break;
            case Level.ALL_INT:
                logLevels |= all << (ii * 3);
                break;
            case Level.DEBUG_INT:
                logLevels |= debug << (ii * 3);
                break;
            case Level.ERROR_INT:
                logLevels |= error << (ii * 3);
                break;
            case Level.FATAL_INT:
                logLevels |= fatal << (ii * 3);
                break;
            case Level.INFO_INT:
                logLevels |= info << (ii * 3);
                break;
            case Level.OFF_INT:
                logLevels |= off << (ii * 3);
                break;
            case Level.WARN_INT:
                logLevels |= warn << (ii * 3);
                break;
                default:
                    throw new RuntimeException("Unhandled log level " + level);
            }
        }
        return logLevels;
    }

    /**
     * All EE loggers will call this static method from C and specify the logger and level
     * they want to log to. The level will be checked again in Java.
     * @param logger index of the logger in the loggers array this statement should be logged to
     * @param level Level of the statement
     * @param statement Statement to log
     */
    public final static void log(int logger, int level, String statement) {
        if (logger < loggers.length) {
            switch (level) {
            case trace:
                loggers[logger].trace(statement);
                break;
            case debug:
                loggers[logger].debug(statement);
                break;
            case error:
                loggers[logger].error(statement);
                break;
            case fatal:
                loggers[logger].fatal(statement);
                break;
            case info:
                loggers[logger].info(statement);
                break;
            case warn:
                loggers[logger].warn(statement);
                break;
                default:
                    throw new RuntimeException("Unhandled log level " + level);
            }
        } else {
            throw new RuntimeException("Attempted to log to logger index " + logger + " which doesn't exist");
        }
    }
}
